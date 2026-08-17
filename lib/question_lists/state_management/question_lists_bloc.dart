import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../db/dependencies.dart' as local_db;
import '../../test/quest/question_features/data/question_difficulty_repository.dart';
import '../data/question_lists_repository.dart';
import '../domain/list_style.dart';
import '../domain/personal_weak_spots.dart';
import '../models/question_list.dart';
import 'question_lists_events.dart';
import 'question_lists_state.dart';

/// App-wide holder of the question lists (provided in `main.dart`, like
/// [AuthBloc] and `FeatureFlagsBloc`), so the home-screen row, the list screen
/// and the "add to list" menu on the question screen all see the same state and
/// update together the instant something changes.
///
/// Custom lists come from [QuestionListsRepository] (optimistic writes, backend
/// storage); the automatic "recent mistakes", "last exam mistakes" and "chronic
/// mistakes" lists are recomputed from the local database.
///
/// "Personal weak spots" also needs the backend (the crowd-difficulty snapshot
/// of the whole bank), so it is **not** loaded on start-up: the first
/// [AutoListsRequested] — the home-screen block or the list's own screen coming
/// into view — triggers it, and from then on it is recomputed together with the
/// other automatic lists.
@injectable
class QuestionListsBloc extends Bloc<QuestionListsEvent, QuestionListsState> {
  QuestionListsBloc(this._lists, this._authBloc, this._difficulty)
    : super(const QuestionListsState()) {
    on<QuestionListsStarted>(_onStarted);
    on<QuestionListsRefreshed>(_onRefreshed);
    on<AutoListsRequested>(_onAutoListsRequested);
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
    on<LastExamMistakesUpdated>(
      (event, emit) => emit(state.copyWith(lastExamMistakes: event.questionIds)),
    );
    on<ChronicMistakesUpdated>(
      (event, emit) => emit(state.copyWith(chronicMistakes: event.questionIds)),
    );
    on<PersonalWeakSpotsUpdated>(
      (event, emit) =>
          emit(state.copyWith(personalWeakSpots: event.questionIds)),
    );
    on<QuestionListsErrorShown>(
      (event, emit) => emit(state.copyWith(errorMessage: null)),
    );
  }

  final QuestionListsRepository _lists;
  final AuthBloc _authBloc;
  final QuestionDifficultyRepository _difficulty;

  StreamSubscription<List<QuestionList>>? _listsSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  /// Whether anything has asked for the automatic lists yet. While this is
  /// false the crowd-difficulty snapshot is never fetched — that is the whole
  /// point of loading "personal weak spots" lazily.
  bool _weakSpotsWanted = false;

  /// The recomputation in flight, so a refresh arriving while the snapshot is
  /// still being fetched does not start a second one.
  Future<void>? _weakSpotsInFlight;

  /// Who the list was computed for (`null` — a guest). Both halves of it belong
  /// to a session, so another user starts from scratch; repeated `authenticated`
  /// states for the *same* user, on the other hand, must not throw the
  /// whole-bank snapshot away and fetch it again.
  String? _weakSpotsUserId;

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
        _onSessionChanged(auth.viewer?.id);
      } else if (auth.status == AuthStatus.unauthenticated) {
        _lists.onLoggedOut();
        // The answer history is wiped on sign-out (`AuthBloc`), so recompute:
        // otherwise the automatic lists keep offering the previous user's
        // mistakes.
        _loadLocalAutoLists();
        _onSessionChanged(null);
      }
    });
    await _lists.bootstrap();
    await _loadLocalAutoLists();
  }

  Future<void> _onRefreshed(
    QuestionListsRefreshed event,
    Emitter<QuestionListsState> emit,
  ) async {
    await _loadLocalAutoLists();
    // Only if the lists have already been shown once: a refresh must not be the
    // thing that pulls the whole-bank snapshot for the first time.
    await _refreshPersonalWeakSpots();
    await _lists.refresh();
  }

  /// The lists came into view. The snapshot is fetched once — later changes
  /// arrive through [QuestionListsRefreshed] — so the event can be dispatched
  /// from `build` as often as the widget rebuilds.
  Future<void> _onAutoListsRequested(
    AutoListsRequested event,
    Emitter<QuestionListsState> emit,
  ) async {
    if (_weakSpotsWanted) return;
    _weakSpotsWanted = true;
    await _refreshPersonalWeakSpots();
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

  /// Re-reads the automatic lists that need nothing but the local database:
  /// "recent mistakes" and "chronic mistakes" (the answer history) and "last
  /// exam mistakes" (the newest `practice_records` row). All three are cheap, so
  /// they are loaded on start-up and on every refresh, unlike "personal weak
  /// spots".
  Future<void> _loadLocalAutoLists() async {
    await Future.wait([
      _loadRecentMistakes(),
      _loadLastExamMistakes(),
      _loadChronicMistakes(),
    ]);
  }

  Future<void> _loadRecentMistakes() async {
    final ids = await local_db.repository.getQuestionsWhereLastAnswerWasWrong();
    add(RecentMistakesUpdated(ids.toList()));
  }

  Future<void> _loadLastExamMistakes() async {
    final ids = await local_db.repository.getLastExamMistakes();
    add(LastExamMistakesUpdated(ids));
  }

  Future<void> _loadChronicMistakes() async {
    final ids = await local_db.repository.getChronicMistakes();
    add(ChronicMistakesUpdated(ids));
  }

  /// The session changed: the cached crowd difficulty belonged to the previous
  /// caller (a guest gets nothing at all), so it is dropped and the list is
  /// recomputed — or cleared outright, so a signed-out user is not left looking
  /// at the previous one's weak spots.
  void _onSessionChanged(String? userId) {
    if (userId == _weakSpotsUserId) return;
    _weakSpotsUserId = userId;
    _difficulty.invalidate();
    if (userId == null) {
      add(PersonalWeakSpotsUpdated(const []));
      return;
    }
    _refreshPersonalWeakSpots();
  }

  /// Recomputes "personal weak spots" — but only once someone has asked for the
  /// automatic lists, and never twice at the same time.
  Future<void> _refreshPersonalWeakSpots() {
    if (!_weakSpotsWanted) return Future.value();
    return _weakSpotsInFlight ??= _computePersonalWeakSpots().whenComplete(() {
      _weakSpotsInFlight = null;
    });
  }

  Future<void> _computePersonalWeakSpots() async {
    // Crowd difficulty is only served to a signed-in caller, and there is
    // nothing sensible to show a guest instead — so the list stays away.
    if (!_authBloc.state.isAuthenticated) {
      add(PersonalWeakSpotsUpdated(const []));
      return;
    }
    try {
      final crowd = await _difficulty.all();
      final mine = await local_db.repository.getWrongAnswerTallies();
      add(PersonalWeakSpotsUpdated(personalWeakSpots(mine: mine, crowd: crowd)));
    } catch (_) {
      // No snapshot (offline, or the backend is down): the card simply is not
      // there. Forget that it was asked for, so the next time the block appears
      // it tries again.
      _weakSpotsWanted = false;
    }
  }

  @override
  Future<void> close() {
    _listsSubscription?.cancel();
    _authSubscription?.cancel();
    return super.close();
  }
}
