import '../models/public_comment.dart';

sealed class CommentsEvent {}

/// Load the first page of comments (and the caller's profile). Dispatched once
/// when the panel opens.
class CommentsStarted extends CommentsEvent {}

/// Reload from the first page (pull-to-refresh / after a write).
class CommentsRefreshed extends CommentsEvent {}

/// Load the next page of top-level comments.
class CommentsLoadMore extends CommentsEvent {}

/// Post a top-level comment ([parentId] null) or a reply. When
/// [displayNameToSet] is non-null the user just entered it in the pre-comment
/// dialog — the Bloc persists it (`setDisplayName`) before posting.
class CommentSubmitted extends CommentsEvent {
  CommentSubmitted(this.body, {this.parentId, this.displayNameToSet});
  final String body;
  final String? parentId;
  final String? displayNameToSet;
}

/// The user accepted the "subscribe to replies" offer for a just-posted comment:
/// ensure push permission/preference, then subscribe to the thread.
class CommentSubscribeAccepted extends CommentsEvent {
  CommentSubscribeAccepted(this.comment);
  final PublicComment comment;
}

/// Dismiss the subscription-offer prompt (shown, declined, or handled).
class SubscriptionPromptDismissed extends CommentsEvent {}

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

/// The user chose "reply" on a comment: target the pinned composer at that
/// thread and move focus into it (without expanding the thread's replies).
class ReplyFocusRequested extends CommentsEvent {
  ReplyFocusRequested(this.topLevelId);
  final String topLevelId;
}

/// Clear the pinned composer's reply target (the × on the "replying to" chip).
class ReplyTargetCleared extends CommentsEvent {}

/// The user confirmed a report of a comment. UI-only while the backend has no
/// reportComment mutation: remembers the id so the menu shows it as reported.
class CommentReported extends CommentsEvent {
  CommentReported(this.id);
  final String id;
}
