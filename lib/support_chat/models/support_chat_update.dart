/// What the realtime support-chat subscription delivers.
///
/// The server's event carries no message body — only *what* changed in *which*
/// thread (`saobracaj_backend`, `SupportChatEvent`), so the screen re-reads the
/// conversation instead of stitching the payload in. Two more things reach an
/// open chat: the news that the socket came up (a reconnect means whatever
/// happened meanwhile was missed) and that it went down.
sealed class SupportChatUpdate {
  const SupportChatUpdate();
}

/// Something changed in the watched conversation.
class SupportChatChanged extends SupportChatUpdate {
  const SupportChatChanged({required this.kind, this.messageId});

  final SupportChangeKind kind;

  /// The message the event is about, when it is about one.
  final String? messageId;
}

/// The subscription is live.
class SupportChatLive extends SupportChatUpdate {
  const SupportChatLive({required this.firstConnect});

  /// `true` on the initial connect (nothing was missed yet), `false` after a
  /// reconnect — in which case the conversation has to be re-read.
  final bool firstConnect;
}

/// The connection dropped; a reconnect is on the way. Until it lands the chat
/// is readable but no longer updates by itself.
class SupportChatOffline extends SupportChatUpdate {
  const SupportChatOffline();
}

/// Mirrors the backend's `SupportChangeKind`.
enum SupportChangeKind {
  /// A new message in the thread — from either side.
  messageAdded,

  /// Somebody read messages, so the ticks on them changed.
  readStateChanged;

  static SupportChangeKind? parse(String? raw) => switch (raw?.toUpperCase()) {
    'MESSAGE_ADDED' => SupportChangeKind.messageAdded,
    'READ_STATE_CHANGED' => SupportChangeKind.readStateChanged,
    _ => null,
  };
}
