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
    @Default(false) bool submitting,
    String? errorMessage,
  }) = _PostCommentsState;

  /// Nobody has commented yet (as opposed to "still loading").
  bool get isEmpty => loaded && comments.isEmpty;
}
