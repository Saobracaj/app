import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

@freezed
abstract class LoginState with _$LoginState {
  const factory LoginState({
    @Default('') String email,
    @Default('') String password,
    @Default(true) bool obscurePassword,
    @Default(false) bool inProgress,
    String? errorMessage,
    // One-shot outcomes consumed by the page's BlocListener.
    @Default(false) bool loggedIn,
    String? needsConfirmationFor,
  }) = _LoginState;
}
