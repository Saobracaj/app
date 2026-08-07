import '../models/support_chat.dart';

/// User actions of the support-chat screen.
sealed class SupportChatEvent {}

/// The screen appeared: load the thread and its messages, mark the counterpart's
/// messages read, and — for the thread's owner — offer notifications once.
class SupportChatOpened extends SupportChatEvent {}

/// Pull-to-refresh / retry after an error.
class SupportChatRefreshed extends SupportChatEvent {}

/// The composer's text changed.
class SupportChatBodyChanged extends SupportChatEvent {
  SupportChatBodyChanged(this.body);
  final String body;
}

/// The user picked a file to attach; it is uploaded immediately and sits as a
/// pending attachment until the message is sent.
class SupportChatAttachPressed extends SupportChatEvent {}

/// Drop a not-yet-sent attachment from the composer.
class SupportChatAttachmentRemoved extends SupportChatEvent {
  SupportChatAttachmentRemoved(this.attachment);
  final SupportAttachment attachment;
}

/// Send the composed message with whatever is attached.
class SupportChatSendPressed extends SupportChatEvent {}

/// The notification offer was declined (or dismissed).
class SupportChatNotificationsDeclined extends SupportChatEvent {}

/// The notification offer was accepted: ask the OS and turn push on.
class SupportChatNotificationsAccepted extends SupportChatEvent {}

/// Clear the inline error banner.
class SupportChatErrorDismissed extends SupportChatEvent {}

/// The backend says the conversation changed (a message was added, or somebody
/// read one). Not dispatched by the UI — it comes off the subscription.
class SupportChatChangedRemotely extends SupportChatEvent {}

/// The realtime connection came up or went down. [missed] is set when it is a
/// reconnect: the server keeps no backlog, so whatever happened while the socket
/// was down has to be re-read.
class SupportChatLiveChanged extends SupportChatEvent {
  SupportChatLiveChanged({required this.live, this.missed = false});

  final bool live;
  final bool missed;
}

/// Upload progress, fed back in from Dio's callback rather than dispatched by
/// the UI. It lives here only because the event hierarchy is sealed.
class SupportChatUploadProgress extends SupportChatEvent {
  SupportChatUploadProgress(this.value);

  /// Fraction of the file already sent, 0..1.
  final double value;
}
