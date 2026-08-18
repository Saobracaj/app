import 'package:freezed_annotation/freezed_annotation.dart';

import '../../question_lists/models/question_list.dart';
import '../../chat/models/chat.dart';
import '../models/group_post.dart';

part 'group_posts_state.freezed.dart';

/// State of one group's wall: the posts loaded so far, where the next page
/// starts, and what the composer is holding.
@freezed
abstract class GroupPostsState with _$GroupPostsState {
  const GroupPostsState._();

  const factory GroupPostsState({
    required String groupId,

    /// Newest first, the order the server pages in.
    @Default(<GroupPost>[]) List<GroupPost> posts,
    @Default(false) bool loading,
    @Default(false) bool loadingMore,

    /// The first page has arrived at least once — until then an empty list is
    /// "not loaded", not "nothing has been posted".
    @Default(false) bool loaded,
    @Default(false) bool hasMore,
    DateTime? nextBefore,
    String? nextBeforeId,

    /// What the composer holds right now.
    @Default('') String body,

    /// Files and images already uploaded and waiting for the post that carries
    /// them.
    @Default(<ChatAttachment>[]) List<ChatAttachment> pending,

    /// Question lists the author picked; shared as a snapshot when the post is
    /// sent, so nothing is uploaded for them.
    @Default(<QuestionList>[]) List<QuestionList> pendingLists,

    /// An upload is in flight — the send button waits for it.
    @Default(false) bool uploading,

    /// The post is being published.
    @Default(false) bool submitting,

    /// The last failure, surfaced once and then cleared.
    String? errorMessage,
  }) = _GroupPostsState;

  /// Nothing has been posted yet (as opposed to "still loading").
  bool get isEmpty => loaded && posts.isEmpty;

  /// Whether the composer holds anything at all.
  bool get hasAttachments => pending.isNotEmpty || pendingLists.isNotEmpty;

  /// Whether the composer may be sent as it stands.
  bool get canSubmit =>
      !submitting && !uploading && (body.trim().isNotEmpty || hasAttachments);
}
