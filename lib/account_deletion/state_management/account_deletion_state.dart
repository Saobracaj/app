import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/account_deletion_preview.dart';

part 'account_deletion_state.freezed.dart';

/// The two screens of the flow: the choices, then the e-mailed code.
enum AccountDeletionStep { options, code }

@freezed
abstract class AccountDeletionState with _$AccountDeletionState {
  const factory AccountDeletionState({
    @Default(true) bool loading,

    /// The preview failed to load — the flow cannot start without it.
    String? loadError,
    @Default(AccountDeletionPreview()) AccountDeletionPreview preview,
    @Default(AccountDeletionStep.options) AccountDeletionStep step,
    // Content choices (the account, e-mail and display name are not choices).
    // Everything optional starts unticked: nothing beyond the mandatory items
    // is deleted unless the user asks for it explicitly.
    @Default(false) bool deletePublicComments,
    @Default(false) bool deleteChatAttachments,
    @Default(false) bool deleteSupportChat,
    @Default(false) bool deleteGroupHistory,
    @Default(false) bool clearLocalData,
    // Consents.
    @Default(false) bool acceptIrreversible,
    @Default(false) bool acceptSubscriptionLoss,
    // The code step.
    @Default('') String code,
    @Default(false) bool inProgress,
    String? errorMessage,

    /// Bumped each time a code was (re)sent, for a one-shot snackbar.
    @Default(0) int codeSentTick,

    /// The account is gone and the session ended.
    @Default(false) bool deleted,
  }) = _AccountDeletionState;

  const AccountDeletionState._();

  /// Deleting the whole conversation implies its attachments — the checklist
  /// shows the row as ticked and locked, and this is what the server is told.
  bool get deletesChatAttachments =>
      deleteChatAttachments || deleteSupportChat;

  /// Everything the server requires before it sends a code is ticked.
  bool get canRequestCode =>
      acceptIrreversible &&
      (!preview.hasActiveSubscription || acceptSubscriptionLoss) &&
      !inProgress;

  bool get canConfirm => code.trim().length == 6 && !inProgress;
}
