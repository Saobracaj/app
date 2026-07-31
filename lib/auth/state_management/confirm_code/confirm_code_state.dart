import 'package:freezed_annotation/freezed_annotation.dart';

part 'confirm_code_state.freezed.dart';

@freezed
abstract class ConfirmCodeState with _$ConfirmCodeState {
  const factory ConfirmCodeState({
    @Default('') String code,
    @Default(false) bool inProgress,
    String? errorMessage,
    // One-shot outcomes consumed by the page's BlocListener.
    @Default(false) bool loggedIn,
    // Bumped each time a new code is successfully resent, so the page can show a
    // confirmation snackbar exactly once per resend.
    @Default(0) int resentTick,
  }) = _ConfirmCodeState;
}
