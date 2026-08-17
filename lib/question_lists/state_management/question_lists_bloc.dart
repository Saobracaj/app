import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../core/network/network_status.dart';
import '../../core/analytics/analytics_service.dart';
import '../../db/dependencies.dart' as local_db;
import '../../test/quest/question_features/data/question_difficulty_repository.dart';
import '../data/question_lists_repository.dart';
import '../data/shared_lists_repository.dart';
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
/// The custom lists are cached, so an offline start renders whatever was there;
/// once the network is back the Bloc pulls them again by itself.
///
/// "Personal weak spots" also needs the backend (the crowd-difficulty snapshot
/// of the whole bank), so it is **not** loaded on start-up: the first
/// [AutoListsRequested] — the home-screen block or the list's own screen coming
/// into view — triggers it, and from then on it is recomputed together with the
/// other automatic lists.
@injectable
class QuestionListsBloc extends Bloc<QuestionListsEvent, QuestionListsState> {
  QuestionListsBloc(
    this._lists,
    this._shares,
    this._authBloc,
    this._analytics,
    this._difficulty,
    this._network,
  )
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
      (event, emit) =>
          emit(state.copyWith(errorMessage: null, shareFailed: false)),
    );
    on<QuestionListShareRequested>(_onShareRequested);
    on<QuestionListShareRevoked>(_onShareRevoked);
    on<QuestionListSharePresented>(
      (event, emit) =>
          emit(state.copyWith(shareToPresent: null, shareRevoked: false)),
    );
    on<QuestionListSharesUpdated>(
      (event, emit) => emit(
        state.copyWith(shares: {for (final s in event.shares) s.listId: s}),
      ),
    );
  }

  final QuestionListsRepository _lists;
  final SharedListsRepository _shares;
  final AuthBloc _authBloc;
  final NetworkStatus _network;
  final AnalyticsService _analytics;
  final QuestionDifficultyRepository _difficulty;

  StreamSubscription<List<QuestionList>>? _listsSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<void>? _reconnectSubscription;

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
        _refreshShares();
        _onSessionChanged(auth.viewer?.id);
      } else if (auth.status == AuthStatus.unauthenticated) {
        _lists.onLoggedOut();
        add(QuestionListSharesUpdated(const []));
        // The answer history is wiped on sign-out (`AuthBloc`), so recompute:
        // otherwise the automatic lists keep offering the previous user's
        // mistakes.
        _loadLocalAutoLists();
        _onSessionChanged(null);
      }
    });
    // Back online: the cached lists may be stale (or absent) — pull them again.
    _reconnectSubscription ??= _network.onReconnected.listen((_) {
      if (_authBloc.state.isAuthenticated) _lists.refresh();
    });
    await _lists.bootstrap();
    await _loadLocalAutoLists();
    await _refreshShares();
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
    await _refreshShares();
  }

  /// Pull the active share links. Best-effort like the lists themselves: a
  /// failure (offline, signed out) keeps whatever is known.
  Future<void> _refreshShares() async {
    if (!_authBloc.state.isAuthenticated) return;
    try {
      add(QuestionListSharesUpdated(await _shares.myShares()));
    } catch (_) {
      // Keep the last known shares.
    }
  }

  /// Share (or re-share — the backend hands back the same code) and queue the
  /// link for the system share sheet.
  Future<void> _onShareRequested(
    QuestionListShareRequested event,
    Emitter<QuestionListsState> emit,
  ) async {
    if (state.shareBusy) return;
    emit(state.copyWith(shareBusy: true, shareFailed: false));
    try {
      final wasShared = state.shares.containsKey(event.listId);
      final share = await _shares.share(event.listId);
      if (!wasShared) {
        _analytics.logQuestionListShared(
          questionCount: state.byId(event.listId)?.questionIds.length ?? 0,
        );
      }
      emit(
        state.copyWith(
          shareBusy: false,
          shares: {...state.shares, share.listId: share},
          shareToPresent: share,
        ),
      );
    } catch (_) {
      emit(state.copyWith(shareBusy: false, shareFailed: true));
    }
  }

  Future<void> _onShareRevoked(
    QuestionListShareRevoked event,
    Emitter<QuestionListsState> emit,
  ) async {
    if (state.shareBusy) return;
    emit(state.copyWith(shareBusy: true, shareFailed: false));
    try {
      await _shares.revoke(event.listId);
      emit(
        state.copyWith(
          shareBusy: false,
          shares: {...state.shares}..remove(event.listId),
          shareRevoked: true,
        ),
      );
    } catch (_) {
      emit(state.copyWith(shareBusy: false, shareFailed: true));
    }
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
  ) => _guard(emit, () => _lists.setQuestions(event.listId, event.questionIds));

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
    _reconnectSubscription?.cancel();
    return super.close();
  }
}
