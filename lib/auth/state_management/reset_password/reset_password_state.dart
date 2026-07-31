import 'package:freezed_annotation/freezed_annotation.dart';

part 'reset_password_state.freezed.dart';

@freezed
abstract class ResetPasswordState with _$ResetPasswordState {
  const factory ResetPasswordState({
    @Default('') String email,
    @Default('') String code,
    @Default('') String newPassword,
    // False = step 1 (enter email). True = step 2 (enter code + new password).
    @Default(false) bool codeSent,
    @Default(false) bool inProgress,
    String? errorMessage,
    // One-shot outcome consumed by the page's BlocListener.
    @Default(false) bool loggedIn,
  }) = _ResetPasswordState;
}
