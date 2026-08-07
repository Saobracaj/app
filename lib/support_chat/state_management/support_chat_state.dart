import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/support_chat.dart';

part 'support_chat_state.freezed.dart';

/// State of one support conversation — the user's own, or (for a moderator) any
/// user's.
@freezed
abstract class SupportChatState with _$SupportChatState {
  const factory SupportChatState({
    @Default(true) bool loading,

    /// The conversation has been read at least once, so what is on screen is
    /// real and not just an empty start.
    @Default(false) bool loaded,

    /// The realtime subscription is up: new messages and read receipts arrive by
    /// themselves. While it is down the chat is readable but stale.
    @Default(false) bool live,
    SupportThread? thread,
    @Default(<SupportMessage>[]) List<SupportMessage> messages,

    /// Composer text.
    @Default('') String body,

    /// Uploaded but not yet sent attachments of the composed message.
    @Default(<SupportAttachment>[]) List<SupportAttachment> pending,

    /// An upload is in flight; [uploadProgress] is 0..1 when known.
    @Default(false) bool uploading,
    @Default(0.0) double uploadProgress,
    @Default(false) bool sending,
    String? errorMessage,

    /// Show the "turn notifications on?" offer (owner's side, asked once).
    @Default(false) bool notificationsPrompt,
  }) = _SupportChatState;

  const SupportChatState._();

  /// Whether the composer has anything worth sending.
  bool get canSend =>
      !sending && !uploading && (body.trim().isNotEmpty || pending.isNotEmpty);

  /// Whether the screen is showing an empty conversation (no messages at all).
  bool get isEmpty => !loading && messages.isEmpty;
}
