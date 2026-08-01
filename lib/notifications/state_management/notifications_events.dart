sealed class NotificationsEvent {}

/// Load stored preferences and check the current OS permission (dispatched once
/// when the screen opens).
class NotificationsStarted extends NotificationsEvent {}

/// Re-check the OS permission — dispatched when the app is resumed, e.g. after
/// the user returns from the system settings.
class AppResumed extends NotificationsEvent {}

class EmailNotificationsToggled extends NotificationsEvent {
  EmailNotificationsToggled(this.enabled);
  final bool enabled;
}

class PushNotificationsToggled extends NotificationsEvent {
  PushNotificationsToggled(this.enabled);
  final bool enabled;
}
