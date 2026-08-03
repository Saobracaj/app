import '../models/public_comment.dart';

sealed class CommentsEvent {}

/// Load the first page of comments (and the caller's profile). Dispatched once
/// when the panel opens.
class CommentsStarted extends CommentsEvent {}

/// Reload from the first page (pull-to-refresh / after a write).
class CommentsRefreshed extends CommentsEvent {}

/// Load the next page of top-level comments.
class CommentsLoadMore extends CommentsEvent {}

/// Post a top-level comment ([parentId] null) or a reply.
class CommentSubmitted extends CommentsEvent {
  CommentSubmitted(this.body, {this.parentId});
  final String body;
  final String? parentId;
}

/// Delete the caller's own comment (or, for a moderator, any comment).
class CommentDeleted extends CommentsEvent {
  CommentDeleted(this.id);
  final String id;
}

/// Toggle the caller's like on a comment (optimistic, with rollback on failure).
class CommentLikeToggled extends CommentsEvent {
  CommentLikeToggled(this.comment);
  final PublicComment comment;
}

/// Toggle the caller's subscription to a top-level comment's replies.
class CommentSubscriptionToggled extends CommentsEvent {
  CommentSubscriptionToggled(this.comment, this.subscribed);
  final PublicComment comment;
  final bool subscribed;
}

/// Reveal the older (hidden) replies of a thread with more than three.
class RepliesExpanded extends CommentsEvent {
  RepliesExpanded(this.topLevelId);
  final String topLevelId;
}
