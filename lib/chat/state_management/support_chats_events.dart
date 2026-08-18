/// User actions of the moderator's list of support conversations.
sealed class SupportChatsEvent {}

/// Load (or reload) the list.
class SupportChatsRequested extends SupportChatsEvent {}

/// Toggle the "only conversations with unread messages" filter.
class SupportChatsFilterToggled extends SupportChatsEvent {
  SupportChatsFilterToggled(this.onlyUnread);
  final bool onlyUnread;
}
