sealed class LoginEvent {}

class EmailChanged extends LoginEvent {
  EmailChanged(this.email);
  final String email;
}

class PasswordChanged extends LoginEvent {
  PasswordChanged(this.password);
  final String password;
}

class TogglePasswordVisibility extends LoginEvent {}

class SubmitPressed extends LoginEvent {}
