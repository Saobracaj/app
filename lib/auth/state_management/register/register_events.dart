sealed class RegisterEvent {}

class EmailChanged extends RegisterEvent {
  EmailChanged(this.email);
  final String email;
}

class PasswordChanged extends RegisterEvent {
  PasswordChanged(this.password);
  final String password;
}

class TogglePasswordVisibility extends RegisterEvent {}

class SubmitPressed extends RegisterEvent {
  SubmitPressed(this.language);

  /// UI language code, forwarded to the back-end so the confirmation email is
  /// localized.
  final String language;
}
