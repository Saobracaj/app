import 'package:freezed_annotation/freezed_annotation.dart';

part 'register_state.freezed.dart';

@freezed
abstract class RegisterState with _$RegisterState {
  const factory RegisterState({
    @Default('') String email,
    @Default('') String password,
    @Default(true) bool obscurePassword,
    @Default(false) bool inProgress,
    String? errorMessage,
    // One-shot outcomes consumed by the page's BlocListener.
    @Default(false) bool loggedIn,
    String? needsConfirmationFor,
  }) = _RegisterState;
}
