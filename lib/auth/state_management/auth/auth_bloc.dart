import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../db/dependencies.dart';
import '../../data/auth_repository.dart';
import 'auth_events.dart';
import 'auth_state.dart';

/// Holds the current session and exposes the notification toggles used by the
/// settings screen. It is the app-wide session holder: it subscribes to
/// [AuthRepository.sessionStatus] and reacts to every transition — auth *flows*
/// (login / register / reset / firebase) run through [AuthRepository] and the
/// stream carries the result here. This mirrors owncup's `AuthBloc`, which
/// listens to its `UserAuthRepository` stream the same way.
@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this.repository) : super(const AuthState()) {
    on<AuthBootstrapRequested>(_onBootstrap);
    on<SessionStatusChanged>(_onSessionStatusChanged);
    on<LogoutRequested>(_onLogout);
    on<EmailNotificationsToggled>(_onEmailNotifications);
    on<PushNotificationsToggled>(_onPushNotifications);

    _sub = repository.sessionStatus
        .distinct()
        .listen((status) => add(SessionStatusChanged(status)));
  }

  final AuthRepository repository;
  late final StreamSubscription<AuthStatus> _sub;

  static const _emailNotifKey = 'notif_email_enabled';
  static const _pushNotifKey = 'notif_push_enabled';

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }

  /// Load persisted notification preferences, then let the repository publish
  /// the stored session on its stream.
  Future<void> _onBootstrap(
    AuthBootstrapRequested event,
    Emitter<AuthState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    emit(
      state.copyWith(
        emailNotifications: prefs.getBool(_emailNotifKey) ?? true,
        pushNotifications: prefs.getBool(_pushNotifKey) ?? true,
      ),
    );
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
      case AuthStatus.unknown:
        emit(state.copyWith(status: AuthStatus.unknown));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) {
    return repository.logout();
  }

  Future<void> _onEmailNotifications(
    EmailNotificationsToggled event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(emailNotifications: event.enabled));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotifKey, event.enabled);
    if (state.isAuthenticated) {
      try {
        await repository.setEmailNotifications(event.enabled);
      } catch (_) {
        // best-effort; the local preference is authoritative for the UI.
      }
    }
  }

  Future<void> _onPushNotifications(
    PushNotificationsToggled event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(pushNotifications: event.enabled));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotifKey, event.enabled);
    if (state.isAuthenticated) {
      try {
        await repository.registerDevice(platform: _platform());
        await repository.setDevicePushEnabled(event.enabled);
      } catch (_) {
        // best-effort; requires a configured FCM token to take full effect.
      }
    }
  }

  String _platform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }
}
