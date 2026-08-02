import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../data/notification_permissions.dart';
import 'notifications_events.dart';
import 'notifications_state.dart';

/// Drives the standalone notifications screen. Email and push preferences are
/// persisted locally (and mirrored to the server when signed in), while the push
/// toggle is gated on the OS notification permission — modelled on owncup's
/// `ProfilePageBloc`:
///
/// * The preference defaults to on (matching the DB default), but if the OS is
///   not granting notifications the switch shows as off.
/// * Turning push on requests the system permission; if it was permanently
///   denied the user is sent to the OS settings instead.
/// * Returning to the app re-checks the permission (see [AppResumed]).
@injectable
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc(this._repository, this._authBloc, this._permissions)
      : super(const NotificationsState()) {
    on<NotificationsStarted>(_onStarted);
    on<AppResumed>(_onAppResumed);
    on<EmailNotificationsToggled>(_onEmail);
    on<PushNotificationsToggled>(_onPush);
  }

  final AuthRepository _repository;
  final AuthBloc _authBloc;
  final NotificationPermissions _permissions;

  static const _emailNotifKey = 'notif_email_enabled';
  static const _pushNotifKey = 'notif_push_enabled';

  bool get _isAuthenticated => _authBloc.state.isAuthenticated;

  Future<void> _onStarted(
    NotificationsStarted event,
    Emitter<NotificationsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final permission = await _permissions.status();
    emit(
      state.copyWith(
        emailNotifications: prefs.getBool(_emailNotifKey) ?? true,
        pushPreference: prefs.getBool(_pushNotifKey) ?? true,
        systemGranted: permission.granted,
        systemPermanentlyDenied: permission.permanentlyDenied,
        loading: false,
      ),
    );
  }

  Future<void> _onAppResumed(
    AppResumed event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state.loading) return;
    final permission = await _permissions.status();
    emit(
      state.copyWith(
        systemGranted: permission.granted,
        systemPermanentlyDenied: permission.permanentlyDenied,
      ),
    );
  }

  Future<void> _onEmail(
    EmailNotificationsToggled event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(emailNotifications: event.enabled));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotifKey, event.enabled);
    if (_isAuthenticated) {
      try {
        await _repository.setEmailNotifications(event.enabled);
      } catch (_) {
        // best-effort; the local preference is authoritative for the UI.
      }
    }
  }

  Future<void> _onPush(
    PushNotificationsToggled event,
    Emitter<NotificationsState> emit,
  ) async {
    if (event.enabled) {
      // Turning push on: make sure the OS actually allows it first.
      final current = await _permissions.status();
      if (current.permanentlyDenied) {
        if (kIsWeb) {
          // The browser won't show the prompt again — the user has to unblock
          // notifications for the site manually.
          emit(state.copyWith(errorMessage: _blockedInBrowserKey));
          emit(state.copyWith(errorMessage: null));
        } else {
          await _permissions.openSettings();
        }
        // The real state is re-read on resume (AppResumed).
        return;
      }
      final granted = await _permissions.request();
      if (!granted.granted) {
        emit(
          state.copyWith(
            systemGranted: false,
            systemPermanentlyDenied: granted.permanentlyDenied,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          pushPreference: true,
          systemGranted: true,
          systemPermanentlyDenied: false,
        ),
      );
      await _persistPush(true);
    } else {
      emit(state.copyWith(pushPreference: false));
      await _persistPush(false);
    }
  }

  Future<void> _persistPush(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotifKey, enabled);
    if (_isAuthenticated) {
      try {
        if (enabled) {
          await _repository.registerDevice(platform: _platform());
        }
        await _repository.setDevicePushEnabled(enabled);
      } catch (_) {
        // best-effort; requires a configured FCM token to take full effect.
      }
    }
  }

  String _platform() => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Key of the localized message shown when notifications are blocked at the
  /// browser level; resolved by the page (blocs stay free of localization).
  static const _blockedInBrowserKey = 'settings.pushBlockedInBrowser';
}
