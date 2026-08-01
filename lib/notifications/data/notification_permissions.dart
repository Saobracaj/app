import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

/// Snapshot of the OS notification-permission state, reduced to the two facts
/// the push toggle cares about.
@immutable
class NotificationPermissionState {
  const NotificationPermissionState({
    required this.granted,
    required this.permanentlyDenied,
  });

  /// The OS currently allows the app to post notifications.
  final bool granted;

  /// The user denied the permission for good — a fresh request would no longer
  /// show the system prompt, so the app has to send them to the OS settings.
  final bool permanentlyDenied;
}

/// Thin wrapper around `permission_handler` for the notification permission,
/// modelled on owncup's `TemporaryNotificationsStatusSolution` extension but
/// pared down to what this app needs.
///
/// On web there is no `permission_handler` notification support (and no FCM
/// wired up here), so the permission is treated as granted and the push toggle
/// behaves as a plain preference.
@lazySingleton
class NotificationPermissions {
  const NotificationPermissions();

  /// Current permission state without prompting the user.
  Future<NotificationPermissionState> status() async {
    if (kIsWeb) return _granted;
    return _map(await Permission.notification.status);
  }

  /// Ask the OS for the notification permission, showing the system prompt when
  /// it is still available.
  Future<NotificationPermissionState> request() async {
    if (kIsWeb) return _granted;
    return _map(await Permission.notification.request());
  }

  /// Open the app's OS settings page so the user can flip a permanently denied
  /// permission back on.
  Future<void> openSettings() => openAppSettings();

  NotificationPermissionState _map(PermissionStatus status) =>
      NotificationPermissionState(
        granted: status.isGranted || status.isLimited,
        permanentlyDenied: status.isPermanentlyDenied || status.isRestricted,
      );

  static const _granted =
      NotificationPermissionState(granted: true, permanentlyDenied: false);
}
