import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';

part 'ask_ai_chat_state.freezed.dart';

/// The Ask-AI chat: the loaded history, the composer's draft, the in-flight
/// send and the daily quota.
///
/// A failed *history* load ([historyFailed]) is separate from a failed *send*
/// ([errorMessage]): the first replaces the conversation with a retry, the
/// second keeps the conversation and the unsent draft.
@freezed
sealed class AskAiChatState with _$AskAiChatState {
  const factory AskAiChatState({
    @Default(true) bool loading,
    @Default(false) bool historyFailed,
    @Default(<AskAiChatMessage>[]) List<AskAiChatMessage> messages,
    @Default('') String body,
    @Default(false) bool sending,

    /// The optimistic bubble of the message being sent — the mutation echoes
    /// only the assistant's reply back, so the user's words live here until
    /// the send settles.
    String? pendingUserText,

    /// The reply streamed so far, while [sending] — rendered inside the
    /// thinking bubble as it grows. Reset by a tool status: whatever the model
    /// said before reaching for a tool was commentary, not the answer.
    @Default('') String streamingText,

    /// The wire name of the tool the model is using right now («ищу похожие
    /// билеты…»), while [sending]; `null` when it is just writing.
    String? streamingTool,
    String? errorMessage,
    AskAiQuota? quota,
  }) = _AskAiChatState;

  const AskAiChatState._();

  bool get quotaExhausted => quota?.exhausted ?? false;

  bool get canSend =>
      !sending && !loading && !quotaExhausted && body.trim().isNotEmpty;

  /// Nothing said yet — the empty state with the suggestion chips.
  bool get isEmpty =>
      !loading && !historyFailed && messages.isEmpty && pendingUserText == null;
}
