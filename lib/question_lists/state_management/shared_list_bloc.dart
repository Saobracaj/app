import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../core/analytics/analytics_service.dart';
import '../data/question_lists_repository.dart';
import '../data/shared_lists_repository.dart';
import '../domain/list_style.dart';
import '../models/question_list.dart';
import 'shared_list_events.dart';
import 'shared_list_state.dart';

/// The `/shared/<code>` screen: resolves a share link to the owner's list and
/// saves a copy on request.
///
/// The copy is a **new** list with a new client-generated id, created through
/// the ordinary [QuestionListsRepository] (so it appears in the home-screen row
/// at once, optimistically) — after that it has nothing to do with the
/// original: each side edits its own.
///
/// A signed-out visitor sees the whole preview; pressing "save" remembers the
/// code in [SharedListsRepository] and asks them to sign in. When they come
/// back to this screen signed in with that code still pending, the import
/// finishes by itself — that is the "resume" half of the flow, driven from
/// `main.dart`, which reopens `/shared/<code>` after a sign-in.
@injectable
class SharedListBloc extends Bloc<SharedListEvent, SharedListState> {
  SharedListBloc(
    @factoryParam String code,
    this._shares,
    this._lists,
    this._authBloc,
    this._analytics,
  ) : super(SharedListState(code: code)) {
    on<SharedListStarted>(_onStarted);
    on<SharedListSaveRequested>(_onSaveRequested);
    on<SharedListImportHandled>(
      (event, emit) => emit(
        state.copyWith(
          importedListId: null,
          signInRequired: false,
          importFailed: false,
        ),
      ),
    );
    on<SharedListSignedIn>((event, emit) => _resumePendingImport(emit));
    // Signing in while this screen is still underneath the login screen (an
    // imperative route, or the same web tab): finish the pending import here.
    _authSubscription = _authBloc.stream.listen((auth) {
      if (auth.status == AuthStatus.authenticated) add(SharedListSignedIn());
    });
  }

  StreamSubscription<AuthState>? _authSubscription;

  final SharedListsRepository _shares;
  final QuestionListsRepository _lists;
  final AuthBloc _authBloc;
  final AnalyticsService _analytics;

  bool get _signedIn => _authBloc.state.isAuthenticated;

  Future<void> _onStarted(
    SharedListStarted event,
    Emitter<SharedListState> emit,
  ) async {
    emit(state.copyWith(loading: true, failure: null));
    try {
      final preview = await _shares.preview(state.code);
      emit(state.copyWith(loading: false, preview: preview));
      _analytics.logSharedListOpened(
        outcome: 'ok',
        questionCount: preview.questionCount,
        viewerIsOwner: preview.viewerIsOwner,
      );
      await _resumePendingImport(emit);
    } on SharedListException catch (e) {
      emit(state.copyWith(loading: false, failure: e.failure));
      _analytics.logSharedListOpened(
        outcome: switch (e.failure) {
          SharedListFailure.linkInvalid => 'link_invalid',
          SharedListFailure.listDeleted => 'list_deleted',
          SharedListFailure.other => 'failed',
        },
      );
    } catch (_) {
      emit(state.copyWith(loading: false, failure: SharedListFailure.other));
      _analytics.logSharedListOpened(outcome: 'failed');
    }
  }

  /// The visitor pressed "save" before signing in and is now back, signed in:
  /// finish what they started. Only *this* code counts — a pending code for
  /// another list is left alone.
  Future<void> _resumePendingImport(Emitter<SharedListState> emit) async {
    if (!_signedIn || state.preview == null || state.importing) return;
    final pending = await _shares.peekPendingImport();
    if (pending == null || !_sameCode(pending, state.code)) return;
    await _shares.clearPendingImport();
    await _import(emit);
  }

  Future<void> _onSaveRequested(
    SharedListSaveRequested event,
    Emitter<SharedListState> emit,
  ) async {
    if (state.preview == null || state.importing) return;
    if (!_signedIn) {
      await _shares.setPendingImport(state.code);
      emit(state.copyWith(signInRequired: true));
      return;
    }
    await _import(emit);
  }

  Future<void> _import(Emitter<SharedListState> emit) async {
    final preview = state.preview;
    if (preview == null || state.importing) return;
    emit(state.copyWith(importing: true, importFailed: false));
    final copy = QuestionList(
      id: genListId(),
      name: preview.name,
      color: preview.color,
      questionIds: preview.questionIds,
    );
    try {
      await _lists.create(copy);
      _analytics.logSharedListImported(questionCount: preview.questionCount);
      emit(state.copyWith(importing: false, importedListId: copy.id));
    } catch (_) {
      emit(state.copyWith(importing: false, importFailed: true));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  /// Codes compare case-insensitively and without dashes/spaces — the same
  /// normalization the backend applies.
  static bool _sameCode(String a, String b) => _canonical(a) == _canonical(b);

  static String _canonical(String code) =>
      code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
}
