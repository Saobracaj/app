import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/group_post.dart';

part 'post_comments_state.freezed.dart';

/// The comments under one post: a flat list, oldest first.
@freezed
abstract class PostCommentsState with _$PostCommentsState {
  const PostCommentsState._();

  const factory PostCommentsState({
    required String postId,
    @Default(<GroupPostComment>[]) List<GroupPostComment> comments,
    @Default(false) bool loading,
    @Default(false) bool loaded,

    /// The read failed: the sheet says so with a retry instead of spinning for
    /// ever, and no snackbar is raised for it.
    @Default(false) bool failed,

    /// That failure was a transport one, so the copy says "no connection".
    @Default(false) bool failedOffline,
    @Default(false) bool submitting,

    /// The last failed *user action* (a comment that was not sent, a delete
    /// that was refused) — surfaced once as a snackbar. Reads never set it.
    String? errorMessage,
  }) = _PostCommentsState;

  /// Nobody has commented yet (as opposed to "still loading").
  bool get isEmpty => loaded && comments.isEmpty;
}
