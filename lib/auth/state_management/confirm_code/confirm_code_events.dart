sealed class ConfirmCodeEvent {}

/// Fired on every keystroke; the bloc auto-submits once the code reaches 6 chars.
class CodeChanged extends ConfirmCodeEvent {
  CodeChanged(this.code);
  final String code;
}

class SubmitPressed extends ConfirmCodeEvent {}

class ResendPressed extends ConfirmCodeEvent {}
