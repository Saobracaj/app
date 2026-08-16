import 'package:freezed_annotation/freezed_annotation.dart';

import '../../support_chat/models/support_chat.dart';

part 'group_post.freezed.dart';

/// One post on a group's wall.
///
/// Its attachments are [SupportAttachment]s and not a type of their own: the
/// backend sends the very same fields for both (`group_posts` reuses the support
/// chat's attachment vocabulary), so the model, the parsing and the widgets are
/// shared rather than copied.
@freezed
abstract class GroupPost with _$GroupPost {
  const factory GroupPost({
    required String id,
    required String groupId,
    required String authorId,
    @Default('') String authorDisplayName,
    @Default('') String body,
    required DateTime createdAt,
    @Default(0) int commentsCount,

    /// Whether the reader may delete it — its author, or the group's owner.
    @Default(false) bool deletableByMe,
    @Default(<SupportAttachment>[]) List<SupportAttachment> attachments,
  }) = _GroupPost;

  const GroupPost._();

  static GroupPost parse(Map<String, dynamic> json) => GroupPost(
    id: json['id'].toString(),
    groupId: json['groupId']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    authorDisplayName: json['authorDisplayName']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
    deletableByMe: json['deletableByMe'] == true,
    attachments:
        (json['attachments'] as List?)
            ?.whereType<Map>()
            .map((e) => SupportAttachment.parse(e.cast<String, dynamic>()))
            .toList() ??
        const <SupportAttachment>[],
  );
}

/// One comment under a post. Flat — a comment cannot be answered.
@freezed
abstract class GroupPostComment with _$GroupPostComment {
  const factory GroupPostComment({
    required String id,
    required String postId,
    required String authorId,
    @Default('') String authorDisplayName,
    @Default('') String body,
    required DateTime createdAt,
    @Default(false) bool deletableByMe,
  }) = _GroupPostComment;

  const GroupPostComment._();

  static GroupPostComment parse(Map<String, dynamic> json) => GroupPostComment(
    id: json['id'].toString(),
    postId: json['postId']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    authorDisplayName: json['authorDisplayName']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    deletableByMe: json['deletableByMe'] == true,
  );
}

/// One page of a wall, newest first, with the cursor the next page continues
/// from — the same shape the group feed pages in.
@freezed
abstract class GroupPostPage with _$GroupPostPage {
  const factory GroupPostPage({
    @Default(<GroupPost>[]) List<GroupPost> posts,
    @Default(false) bool hasMore,
    DateTime? nextBefore,
    String? nextBeforeId,
  }) = _GroupPostPage;

  const GroupPostPage._();

  static GroupPostPage parse(Map<String, dynamic> json) => GroupPostPage(
    posts:
        (json['posts'] as List?)
            ?.whereType<Map>()
            .map((e) => GroupPost.parse(e.cast<String, dynamic>()))
            .toList() ??
        const <GroupPost>[],
    hasMore: json['hasMore'] == true,
    nextBefore: DateTime.tryParse(json['nextBefore']?.toString() ?? ''),
    nextBeforeId: json['nextBeforeId']?.toString(),
  );
}
