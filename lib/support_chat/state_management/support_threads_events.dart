/// User actions of the moderator's list of support conversations.
sealed class SupportThreadsEvent {}

/// Load (or reload) the list.
class SupportThreadsRequested extends SupportThreadsEvent {}

/// Toggle the "only conversations with unread messages" filter.
class SupportThreadsFilterToggled extends SupportThreadsEvent {
  SupportThreadsFilterToggled(this.onlyUnread);
  final bool onlyUnread;
}
