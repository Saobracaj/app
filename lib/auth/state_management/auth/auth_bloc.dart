import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../account_deletion/data/local_data_cleaner.dart';
import '../../../core/network/network_status.dart';
import '../../../db/dependencies.dart';
import '../../data/auth_repository.dart';
import '../../data/graphql_subscription_client.dart';
import 'auth_events.dart';
import 'auth_state.dart';

/// App-wide session holder: it subscribes to [AuthRepository.sessionStatus] and
/// reacts to every transition — auth *flows* (login / register / reset /
/// firebase) run through [AuthRepository] and the stream carries the result
/// here. This mirrors owncup's `AuthBloc`, which listens to its
/// `UserAuthRepository` stream the same way. Notification preferences live in
/// their own feature (`lib/notifications/`).
@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this.repository,
    this.subscriptions, {
    LocalDataCleaner? localData,
    NetworkStatus? network,
  }) : localData = localData ?? LocalDataCleaner(),
       super(const AuthState()) {
    on<AuthBootstrapRequested>(_onBootstrap);
    on<SessionStatusChanged>(_onSessionStatusChanged);
    on<NetworkReconnected>(_onNetworkReconnected);
    on<LogoutRequested>(_onLogout);
    on<AccountDeleted>(_onAccountDeleted);

    _sub = repository.sessionStatus.distinct().listen(
      (status) => add(SessionStatusChanged(status)),
    );
    // Optional so tests can build the Bloc without the platform plugin; the DI
    // registration always passes the app-wide instance.
    _reconnectSub = network?.onReconnected.listen(
      (_) => add(NetworkReconnected()),
    );
  }

  final AuthRepository repository;

  /// The websocket transport, closed when the session ends — a live
  /// subscription belongs to the user who opened it.
  final GraphqlSubscriptionClient subscriptions;

  /// Wipes the device-side history when a deleted account asked for it.
  final LocalDataCleaner localData;

  late final StreamSubscription<AuthStatus> _sub;
  StreamSubscription<void>? _reconnectSub;

  /// Set by [AccountDeleted] when the user chose to keep the local history:
  /// the very next sign-out then leaves the local statistics alone (see
  /// [AccountDeleted]). One-shot — a later ordinary sign-out wipes as usual.
  bool _keepLocalStatisticsOnce = false;

  @override
  Future<void> close() {
    _sub.cancel();
    _reconnectSub?.cancel();
    return super.close();
  }

  /// Back online with a session: catch up on what the offline start skipped.
  /// The viewer is only fetched when it is missing (an offline start keeps the
  /// session but has no profile), the grants are always refreshed — cheap, and
  /// premium may have been bought on another device meanwhile.
  Future<void> _onNetworkReconnected(
    NetworkReconnected event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != AuthStatus.authenticated) return;
    featureFlags.refreshFromBackend();
    statisticsSync.sync();
    if (state.viewer != null) return;
    try {
      final viewer = await repository.me();
      if (viewer != null && state.status == AuthStatus.authenticated) {
        emit(state.copyWith(viewer: viewer));
      }
    } catch (_) {
      // Still offline or transient — the next reconnect tries again.
    }
  }

  /// Let the repository publish the stored session on its stream.
  Future<void> _onBootstrap(
    AuthBootstrapRequested event,
    Emitter<AuthState> emit,
  ) async {
    await repository.bootstrap();
  }

  Future<void> _onSessionStatusChanged(
    SessionStatusChanged event,
    Emitter<AuthState> emit,
  ) async {
    switch (event.status) {
      case AuthStatus.authenticated:
        emit(state.copyWith(status: AuthStatus.authenticated));
        // Merge any statistics gathered before login and pull down anything
        // stored from other devices.
        statisticsSync.sync();
        // Refresh which premium features this account has been granted.
        featureFlags.refreshFromBackend();
        try {
          // A merely expired access token is refreshed inside the client, so
          // reaching this call with a live session is enough to get a viewer.
          final viewer = await repository.me();
          if (viewer != null) {
            emit(state.copyWith(viewer: viewer));
          } else {
            // The account behind the token is gone — drop it (re-emits
            // unauthenticated).
            await repository.logout();
          }
        } catch (_) {
          // Offline / transient: keep the authenticated session without a
          // fresh profile. A definitively expired session is not handled here —
          // the client reports it on `sessionExpired` and the repository signs
          // out, which arrives as an `unauthenticated` transition.
        }
      case AuthStatus.unauthenticated:
        // Statistics are tied to the account that produced them: leaving them
        // behind would merge this user's results into the next account signing
        // in on this device. Only a transition *out of* a live session is a
        // real sign-out — `unauthenticated` is also how the very first
        // bootstrap reports "no stored session", and a guest's own history must
        // survive that. Cleared before the new state is published, so whatever
        // reacts to the logout (e.g. the "recent mistakes" row) already reads an
        // empty database.
        if (state.status == AuthStatus.authenticated) {
          final keep = _keepLocalStatisticsOnce;
          _keepLocalStatisticsOnce = false;
          await statisticsSync.onLoggedOut(keepLocalRecords: keep);
        }
        emit(
          state.copyWith(status: AuthStatus.unauthenticated, clearViewer: true),
        );
        // Premium features are tied to the session — drop the cached grants.
        featureFlags.onLoggedOut();
        // Same for anything listening over the websocket: the token it
        // authenticated with is no longer valid.
        unawaited(subscriptions.reset());
      case AuthStatus.unknown:
        emit(state.copyWith(status: AuthStatus.unknown));
    }
  }

  /// User-initiated sign-out. Flush first: the local statistics are wiped once
  /// the session ends, so this is the last chance to upload anything gathered
  /// since the previous sync (a test finished while offline). Bounded, because
  /// signing out must not hang on a dead network — and never fatal, since
  /// `sync()` swallows its own errors.
  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await statisticsSync.sync().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
    await repository.logout();
  }

  /// The server has already anonymised the account, so nothing is synced: the
  /// records it held are gone. Wipe the device on request, then end the session
  /// — the token is dead anyway (the account's e-mail changed).
  Future<void> _onAccountDeleted(
    AccountDeleted event,
    Emitter<AuthState> emit,
  ) async {
    _keepLocalStatisticsOnce = !event.clearLocalData;
    if (event.clearLocalData) {
      await localData.wipe();
    }
    await repository.logout();
  }
}
