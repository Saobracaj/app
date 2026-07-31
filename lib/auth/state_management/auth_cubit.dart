import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../db/dependencies.dart';
import '../data/auth_repository.dart';
import '../models/viewer.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide authentication state. Also carries the locally stored notification
/// preferences so the settings screen can reflect them without an extra query.
@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.viewer,
    this.emailNotifications = true,
    this.pushNotifications = true,
  });

  final AuthStatus status;
  final Viewer? viewer;
  final bool emailNotifications;
  final bool pushNotifications;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    Viewer? viewer,
    bool clearViewer = false,
    bool? emailNotifications,
    bool? pushNotifications,
  }) => AuthState(
    status: status ?? this.status,
    viewer: clearViewer ? null : (viewer ?? this.viewer),
    emailNotifications: emailNotifications ?? this.emailNotifications,
    pushNotifications: pushNotifications ?? this.pushNotifications,
  );
}

/// Holds the current session and exposes the notification toggles used by the
/// settings screen. Auth *flows* (login/register/reset) are driven directly from
/// their pages through [repository]; this cubit owns the resulting session.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.repository) : super(const AuthState());

  final AuthRepository repository;

  static const _emailNotifKey = 'notif_email_enabled';
  static const _pushNotifKey = 'notif_push_enabled';

  /// Restore any persisted session on startup and validate it with `me`.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final emailNotif = prefs.getBool(_emailNotifKey) ?? true;
    final pushNotif = prefs.getBool(_pushNotifKey) ?? true;

    if (!await repository.hasStoredSession()) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          emailNotifications: emailNotif,
          pushNotifications: pushNotif,
        ),
      );
      return;
    }
    try {
      final viewer = await repository.me();
      if (viewer != null) {
        emit(
          AuthState(
            status: AuthStatus.authenticated,
            viewer: viewer,
            emailNotifications: emailNotif,
            pushNotifications: pushNotif,
          ),
        );
        // Pull the latest statistics from the back-end on startup.
        statisticsSync.sync();
        return;
      }
    } catch (_) {
      // Session invalid / offline — treat as logged out but keep prefs.
    }
    await repository.logout();
    emit(
      AuthState(
        status: AuthStatus.unauthenticated,
        emailNotifications: emailNotif,
        pushNotifications: pushNotif,
      ),
    );
  }

  /// Mark the session as authenticated after a successful auth flow, then load
  /// the profile.
  Future<void> onAuthenticated() async {
    emit(state.copyWith(status: AuthStatus.authenticated));
    // Merge any statistics gathered before login with the back-end, and pull
    // down anything stored from other devices.
    statisticsSync.sync();
    try {
      final viewer = await repository.me();
      if (viewer != null) emit(state.copyWith(viewer: viewer));
    } catch (_) {
      // Non-fatal: keep the authenticated status without profile details.
    }
  }

  Future<void> logout() async {
    await repository.logout();
    emit(
      AuthState(
        status: AuthStatus.unauthenticated,
        emailNotifications: state.emailNotifications,
        pushNotifications: state.pushNotifications,
      ),
    );
  }

  Future<void> setEmailNotifications(bool enabled) async {
    emit(state.copyWith(emailNotifications: enabled));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotifKey, enabled);
    if (state.isAuthenticated) {
      try {
        await repository.setEmailNotifications(enabled);
      } catch (_) {
        // best-effort; the local preference is authoritative for the UI.
      }
    }
  }

  Future<void> setPushNotifications(bool enabled) async {
    emit(state.copyWith(pushNotifications: enabled));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotifKey, enabled);
    if (state.isAuthenticated) {
      try {
        await repository.registerDevice(platform: _platform());
        await repository.setDevicePushEnabled(enabled);
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
