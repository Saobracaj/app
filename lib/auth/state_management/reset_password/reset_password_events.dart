sealed class ResetPasswordEvent {}

class EmailChanged extends ResetPasswordEvent {
  EmailChanged(this.email);
  final String email;
}

class CodeChanged extends ResetPasswordEvent {
  CodeChanged(this.code);
  final String code;
}

class NewPasswordChanged extends ResetPasswordEvent {
  NewPasswordChanged(this.newPassword);
  final String newPassword;
}

class TogglePasswordVisibility extends ResetPasswordEvent {}

/// Step 1: request a reset code by email.
class SendCodePressed extends ResetPasswordEvent {}

/// Step 2: submit the code + new password.
class ConfirmPressed extends ResetPasswordEvent {}
