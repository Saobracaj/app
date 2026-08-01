import 'package:freezed_annotation/freezed_annotation.dart';

part 'notifications_state.freezed.dart';

/// State for the standalone notifications screen. Email is a plain preference;
/// push additionally depends on the OS permission — [pushPreference] mirrors the
/// stored/DB preference (default on), but the switch shown to the user reflects
/// [pushEnabled], which is off whenever the OS is not granting notifications.
@freezed
abstract class NotificationsState with _$NotificationsState {
  const factory NotificationsState({
    @Default(true) bool emailNotifications,
    @Default(true) bool pushPreference,
    @Default(true) bool systemGranted,
    @Default(false) bool systemPermanentlyDenied,
    @Default(true) bool loading,
    String? errorMessage,
  }) = _NotificationsState;

  const NotificationsState._();

  /// Effective value of the push switch: the user opted in *and* the OS allows
  /// notifications on this device.
  bool get pushEnabled => pushPreference && systemGranted;
}
