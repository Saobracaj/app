import '../models/group_event.dart';

/// What can happen to the feed screen: the reader scrolling, and the server
/// pushing.
sealed class GroupFeedBlocEvent {
  const GroupFeedBlocEvent();
}

/// The screen opened: load the newest page and go live.
class GroupFeedOpened extends GroupFeedBlocEvent {
  const GroupFeedOpened();
}

/// Pull-to-refresh: re-read the newest page, keeping what is already loaded.
class GroupFeedRefreshed extends GroupFeedBlocEvent {
  const GroupFeedRefreshed();
}

/// The reader reached the bottom: load the page behind the cursor.
class GroupFeedMoreRequested extends GroupFeedBlocEvent {
  const GroupFeedMoreRequested();
}

/// An event arrived over the subscription.
class GroupFeedEventArrived extends GroupFeedBlocEvent {
  const GroupFeedEventArrived(this.event);

  final GroupEvent event;
}

/// The subscription connected. After a *re*connect the head is re-read: the
/// server streams only what happens from now on, so the time the socket was
/// down would otherwise be a hole in the list.
class GroupFeedLiveChanged extends GroupFeedBlocEvent {
  const GroupFeedLiveChanged({required this.live, required this.missedEvents});

  final bool live;

  /// Whether events may have been missed while the connection was down.
  final bool missedEvents;
}

/// The error message was shown; clear it.
class GroupFeedErrorShown extends GroupFeedBlocEvent {
  const GroupFeedErrorShown();
}
