/// Coarse session status published by [AuthRepository.sessionStatus] and mirrored
/// into the app-wide [AuthState] by the `AuthBloc`.
///
/// This is the single source of truth for "is the user signed in": auth *flows*
/// (login / register / reset / firebase) run through [AuthRepository], which
/// emits the resulting status on its stream — the same reactive pattern owncup
/// uses with its `UserAuthRepository`/`AuthBloc` pair.
enum AuthStatus { unknown, authenticated, unauthenticated }
