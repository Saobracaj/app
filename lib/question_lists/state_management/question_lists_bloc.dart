import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../db/dependencies.dart' as local_db;
import '../data/question_lists_repository.dart';
import '../domain/list_style.dart';
import '../models/question_list.dart';
import 'question_lists_events.dart';
import 'question_lists_state.dart';

/// App-wide holder of the question lists (provided in `main.dart`, like
/// [AuthBloc] and `FeatureFlagsBloc`), so the home-screen row, the list screen
/// and the "add to list" menu on the question screen all see the same state and
/// update together the instant something changes.
///
/// Custom lists come from [QuestionListsRepository] (optimistic writes, backend
/// storage); the automatic "recent mistakes" list is recomputed from the local
/// answer history.
@injectable
class QuestionListsBloc extends Bloc<QuestionListsEvent, QuestionListsState> {
  QuestionListsBloc(this._lists, this._authBloc)
    : super(const QuestionListsState()) {
    on<QuestionListsStarted>(_onStarted);
    on<QuestionListsRefreshed>(_onRefreshed);
    on<QuestionListCreated>(_onCreated);
    on<QuestionListEdited>(_onEdited);
    on<QuestionListDeleted>(_onDeleted);
    on<QuestionInListToggled>(_onQuestionToggled);
    on<QuestionListQuestionsChanged>(_onQuestionsChanged);
    on<QuestionListsUpdated>(
      (event, emit) => emit(state.copyWith(customLists: event.lists)),
    );
    on<RecentMistakesUpdated>(
      (event, emit) => emit(state.copyWith(recentMistakes: event.questionIds)),
    );
    on<QuestionListsErrorShown>(
      (event, emit) => emit(state.copyWith(errorMessage: null)),
    );
  }

  final QuestionListsRepository _lists;
  final AuthBloc _authBloc;

  StreamSubscription<List<QuestionList>>? _listsSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  Future<void> _onStarted(
    QuestionListsStarted event,
    Emitter<QuestionListsState> emit,
  ) async {
    _listsSubscription ??= _lists.changes.listen(
      (lists) => add(QuestionListsUpdated(lists)),
    );
    // Custom lists belong to a user: refresh them on login, drop them on logout.
    _authSubscription ??= _authBloc.stream.listen((auth) {
      if (auth.isAuthenticated) {
        _lists.refresh();
      } else if (auth.status == AuthStatus.unauthenticated) {
        _lists.onLoggedOut();
        // The answer history is wiped on sign-out (`AuthBloc`), so recompute:
        // otherwise the automatic list keeps offering the previous user's
        // mistakes.
        _loadRecentMistakes();
      }
    });
    await _lists.bootstrap();
    await _loadRecentMistakes();
  }

  Future<void> _onRefreshed(
    QuestionListsRefreshed event,
    Emitter<QuestionListsState> emit,
  ) async {
    await _loadRecentMistakes();
    await _lists.refresh();
  }

  Future<void> _onCreated(
    QuestionListCreated event,
    Emitter<QuestionListsState> emit,
  ) => _guard(
    emit,
    () => _lists.create(
      QuestionList(
        id: genListId(),
        name: event.name,
        color: event.color,
        questionIds: event.questionId == null ? const [] : [event.questionId!],
      ),
    ),
  );

  Future<void> _onEdited(
    QuestionListEdited event,
    Emitter<QuestionListsState> emit,
  ) => _guard(
    emit,
    () => _lists.update(event.id, name: event.name, color: event.color),
  );

  Future<void> _onDeleted(
    QuestionListDeleted event,
    Emitter<QuestionListsState> emit,
  ) => _guard(emit, () => _lists.delete(event.id));

  Future<void> _onQuestionToggled(
    QuestionInListToggled event,
    Emitter<QuestionListsState> emit,
  ) => _guard(
    emit,
    () => _lists.setQuestionIncluded(
      event.listId,
      event.questionId,
      event.included,
    ),
  );

  Future<void> _onQuestionsChanged(
    QuestionListQuestionsChanged event,
    Emitter<QuestionListsState> emit,
  ) => _guard(
    emit,
    () => _lists.setQuestions(event.listId, event.questionIds),
  );

  /// Runs a repository write. The repository already applied the change locally
  /// and rolled it back on failure, so all that is left here is to surface the
  /// error once.
  Future<void> _guard(
    Emitter<QuestionListsState> emit,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!emit.isDone) emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _loadRecentMistakes() async {
    final ids = await local_db.repository.getQuestionsWhereLastAnswerWasWrong();
    add(RecentMistakesUpdated(ids.toList()));
  }

  @override
  Future<void> close() {
    _listsSubscription?.cancel();
    _authSubscription?.cancel();
    return super.close();
  }
}
