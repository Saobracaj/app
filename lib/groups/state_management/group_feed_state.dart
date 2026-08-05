import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/group_event.dart';

part 'group_feed_state.freezed.dart';

/// State of one group's activity feed: the events loaded so far, where the next
/// page starts, and whether the live connection is up.
@freezed
abstract class GroupFeedState with _$GroupFeedState {
  const GroupFeedState._();

  const factory GroupFeedState({
    required String groupId,

    /// The group's name, for the app bar. Known as soon as the home screen has
    /// loaded the user's groups; empty until then.
    @Default('') String groupName,

    /// Newest first, the same order the server pages in.
    @Default(<GroupEvent>[]) List<GroupEvent> events,

    /// The first page is loading.
    @Default(false) bool loading,

    /// The next page is loading (the spinner at the bottom of the list).
    @Default(false) bool loadingMore,

    /// The first page has arrived at least once — until then an empty list is
    /// "not loaded", not "nothing happened".
    @Default(false) bool loaded,

    /// There is more history behind the cursor below.
    @Default(false) bool hasMore,

    /// Cursor of the next page: the pair the server handed back.
    DateTime? nextBefore,
    String? nextBeforeId,

    /// The subscription is connected, so new events arrive on their own.
    @Default(false) bool live,

    /// The last failure, surfaced once and then cleared.
    String? errorMessage,
  }) = _GroupFeedState;

  /// Nothing has ever happened in this group (as opposed to "still loading").
  bool get isEmpty => loaded && events.isEmpty;

  /// The oldest event on screen — everything below it is still unread history.
  GroupEvent? get oldest => events.isEmpty ? null : events.last;
}
