import '../../data/auth_status.dart';

sealed class AuthEvent {}

/// Restore any persisted session on startup (dispatched once from `main`).
class AuthBootstrapRequested extends AuthEvent {}

/// Emitted internally whenever [AuthRepository.sessionStatus] transitions.
class SessionStatusChanged extends AuthEvent {
  SessionStatusChanged(this.status);
  final AuthStatus status;
}

/// User asked to sign out.
class LogoutRequested extends AuthEvent {}
