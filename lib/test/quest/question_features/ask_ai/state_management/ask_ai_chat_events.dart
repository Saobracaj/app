import 'package:saobracaj/test/quest/question_features/ask_ai/models/ask_ai_chat.dart';

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

/// An `askAiStream` frame arrived — the reply in progress grew, or the model
/// reached for a tool. Fed by the Bloc's own subscription, not by widgets.
class AskAiChatStreamed extends AskAiChatEvent {
  AskAiChatStreamed(this.update);
  final AskAiStreamUpdate update;
}
