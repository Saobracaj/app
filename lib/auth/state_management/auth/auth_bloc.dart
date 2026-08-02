import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../db/dependencies.dart';
import '../../data/auth_repository.dart';
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
  AuthBloc(this.repository) : super(const AuthState()) {
    on<AuthBootstrapRequested>(_onBootstrap);
    on<SessionStatusChanged>(_onSessionStatusChanged);
    on<LogoutRequested>(_onLogout);

    _sub = repository.sessionStatus
        .distinct()
        .listen((status) => add(SessionStatusChanged(status)));
  }

  final AuthRepository repository;
  late final StreamSubscription<AuthStatus> _sub;

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
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
          final viewer = await repository.me();
          if (viewer != null) {
            emit(state.copyWith(viewer: viewer));
          } else {
            // Token is no longer valid — drop it (re-emits unauthenticated).
            await repository.logout();
          }
        } catch (_) {
          // Offline / transient: keep the authenticated session without a
          // fresh profile.
        }
      case AuthStatus.unauthenticated:
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearViewer: true));
        // Premium features are tied to the session — drop the cached grants.
        featureFlags.onLoggedOut();
      case AuthStatus.unknown:
        emit(state.copyWith(status: AuthStatus.unknown));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) {
    return repository.logout();
  }
}
