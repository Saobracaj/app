/// What can happen in the Ask-AI chat.
sealed class AskAiChatEvent {}

/// The chat became visible: load the history and the daily quota.
/// Also serves as the retry after a failed history load.
class AskAiChatOpened extends AskAiChatEvent {}

class AskAiChatBodyChanged extends AskAiChatEvent {
  AskAiChatBodyChanged(this.body);
  final String body;
}

/// Send the composer's draft, or — for a suggestion chip — the chip's ready
/// question.
class AskAiChatSendPressed extends AskAiChatEvent {
  AskAiChatSendPressed({this.text});

  /// When set, this is sent instead of the draft (the suggestion chips).
  final String? text;
}

class AskAiChatErrorDismissed extends AskAiChatEvent {}
