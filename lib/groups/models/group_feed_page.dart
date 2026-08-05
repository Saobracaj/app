import 'package:freezed_annotation/freezed_annotation.dart';

import 'group_event.dart';

part 'group_feed_page.freezed.dart';

/// One page of a group's feed, newest first — the `GroupFeedPage` GraphQL type.
///
/// Paging is by cursor rather than by offset: several events can share a
/// timestamp (one sync uploads a batch of results), so the cursor is the pair
/// `(occurredAt, id)` and [nextBefore]/[nextBeforeId] go straight back into the
/// next `groupFeed` call.
@freezed
abstract class GroupFeedPage with _$GroupFeedPage {
  const factory GroupFeedPage({
    @Default(<GroupEvent>[]) List<GroupEvent> events,
    @Default(false) bool hasMore,
    DateTime? nextBefore,
    String? nextBeforeId,
  }) = _GroupFeedPage;

  factory GroupFeedPage.fromJson(Map<String, dynamic> json) {
    final raw = json['events'];
    return GroupFeedPage(
      events: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => GroupEvent.fromJson(e.cast<String, dynamic>()))
                .where((e) => e.isRenderable)
                .toList()
          : const [],
      hasMore: json['hasMore'] == true,
      nextBefore: DateTime.tryParse(json['nextBefore']?.toString() ?? ''),
      nextBeforeId: json['nextBeforeId']?.toString(),
    );
  }
}
