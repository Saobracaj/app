/// What the realtime chat subscription delivers.
///
/// The server's event carries no message body — only *what* changed in *which*
/// thread (`saobracaj_backend`, `ChatEvent`), so the screen re-reads the
/// conversation instead of stitching the payload in. Two more things reach an
/// open chat: the news that the socket came up (a reconnect means whatever
/// happened meanwhile was missed) and that it went down.
sealed class ChatUpdate {
  const ChatUpdate();
}

/// Something changed in the watched conversation.
class ChatChanged extends ChatUpdate {
  const ChatChanged({required this.kind, this.messageId});

  final ChatChangeKind kind;

  /// The message the event is about, when it is about one.
  final String? messageId;
}

/// The subscription is live.
class ChatLive extends ChatUpdate {
  const ChatLive({required this.firstConnect});

  /// `true` on the initial connect (nothing was missed yet), `false` after a
  /// reconnect — in which case the conversation has to be re-read.
  final bool firstConnect;
}

/// The connection dropped; a reconnect is on the way. Until it lands the chat
/// is readable but no longer updates by itself.
class ChatOffline extends ChatUpdate {
  const ChatOffline();
}

/// Mirrors the backend's `ChatChangeKind`.
enum ChatChangeKind {
  /// A new message in the conversation — from any participant.
  messageAdded,

  /// Somebody rewrote their message.
  messageEdited,

  /// Somebody read messages, so the ticks on them changed.
  readStateChanged,

  /// A thread was opened on a message of this conversation, so its reply link
  /// appears.
  threadOpened;

  static ChatChangeKind? parse(String? raw) => switch (raw?.toUpperCase()) {
    'MESSAGE_ADDED' => ChatChangeKind.messageAdded,
    'MESSAGE_EDITED' => ChatChangeKind.messageEdited,
    'READ_STATE_CHANGED' => ChatChangeKind.readStateChanged,
    'THREAD_OPENED' => ChatChangeKind.threadOpened,
    _ => null,
  };
}
