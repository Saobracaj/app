sealed class AccountDeletionEvent {}

/// Load the preview (counts, subscription).
class AccountDeletionStarted extends AccountDeletionEvent {}

/// One of the content checkboxes / consents was toggled.
class DeletePublicCommentsToggled extends AccountDeletionEvent {
  DeletePublicCommentsToggled(this.value);
  final bool value;
}

class DeleteChatAttachmentsToggled extends AccountDeletionEvent {
  DeleteChatAttachmentsToggled(this.value);
  final bool value;
}

class DeleteSupportChatToggled extends AccountDeletionEvent {
  DeleteSupportChatToggled(this.value);
  final bool value;
}

class DeleteGroupHistoryToggled extends AccountDeletionEvent {
  DeleteGroupHistoryToggled(this.value);
  final bool value;
}

class ClearLocalDataToggled extends AccountDeletionEvent {
  ClearLocalDataToggled(this.value);
  final bool value;
}

class AcceptIrreversibleToggled extends AccountDeletionEvent {
  AcceptIrreversibleToggled(this.value);
  final bool value;
}

class AcceptSubscriptionLossToggled extends AccountDeletionEvent {
  AcceptSubscriptionLossToggled(this.value);
  final bool value;
}

/// «Send confirmation code» — moves to the code step on success.
class RequestCodePressed extends AccountDeletionEvent {}

/// «Send the code again» on the code step.
class ResendCodePressed extends AccountDeletionEvent {}

/// Back from the code step to the choices.
class BackToOptionsPressed extends AccountDeletionEvent {}

class CodeChanged extends AccountDeletionEvent {
  CodeChanged(this.code);
  final String code;
}

/// «Delete the account forever».
class ConfirmDeletePressed extends AccountDeletionEvent {}
