import '../../data/auth_status.dart';

sealed class AuthEvent {}

/// Restore any persisted session on startup (dispatched once from `main`).
class AuthBootstrapRequested extends AuthEvent {}

/// Emitted internally whenever [AuthRepository.sessionStatus] transitions.
class SessionStatusChanged extends AuthEvent {
  SessionStatusChanged(this.status);
  final AuthStatus status;
}

/// The network came back (internal, from `NetworkStatus`): re-validate the
/// session and refresh what an offline start could not fetch — the viewer (its
/// permissions gate the editor UI) and the account's feature grants.
class NetworkReconnected extends AuthEvent {}

/// User asked to sign out.
class LogoutRequested extends AuthEvent {}

/// The account was just deleted on the server; end the session. Unlike a plain
/// sign-out the local statistics are *kept* unless [clearLocalData] — there is
/// no account left they could be pulled back from, so wiping them would throw
/// away the only copy; the user chose whether to keep them as a guest's
/// history. With [clearLocalData] every local trace goes (statistics, caches).
class AccountDeleted extends AuthEvent {
  AccountDeleted({required this.clearLocalData});
  final bool clearLocalData;
}
