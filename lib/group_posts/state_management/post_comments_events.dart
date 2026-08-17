/// What can happen in the comments under one post.
sealed class PostCommentsBlocEvent {
  const PostCommentsBlocEvent();
}

/// The sheet opened, or was pulled to refresh: read the comments.
class PostCommentsLoaded extends PostCommentsBlocEvent {
  const PostCommentsLoaded();
}

/// Send what the field holds.
class PostCommentSubmitted extends PostCommentsBlocEvent {
  const PostCommentSubmitted(this.body);

  final String body;
}

/// Delete a comment — its author, the post's author, or the group's owner.
class PostCommentDeleted extends PostCommentsBlocEvent {
  const PostCommentDeleted(this.commentId);

  final String commentId;
}

/// The error message was shown; clear it.
class PostCommentsErrorShown extends PostCommentsBlocEvent {
  const PostCommentsErrorShown();
}
