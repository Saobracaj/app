import 'group_event.dart';

/// What the live feed subscription delivers.
///
/// Two things can reach an open feed screen: a new event, or the news that the
/// connection was (re)established. The second matters because the subscription
/// carries no backlog — everything that happened while the socket was down was
/// missed, so the screen re-reads the newest page instead of leaving a hole in
/// the middle of the list.
sealed class GroupFeedUpdate {
  const GroupFeedUpdate();
}

/// A new event in the group.
class GroupFeedEventReceived extends GroupFeedUpdate {
  const GroupFeedEventReceived(this.event);

  final GroupEvent event;
}

/// The connection dropped; a reconnect is on the way. Until it lands, new
/// events are not arriving.
class GroupFeedInterrupted extends GroupFeedUpdate {
  const GroupFeedInterrupted();
}

/// The subscription is live.
class GroupFeedResumed extends GroupFeedUpdate {
  const GroupFeedResumed({required this.firstConnect});

  /// `true` on the initial connect (nothing was missed yet), `false` after a
  /// reconnect.
  final bool firstConnect;
}
