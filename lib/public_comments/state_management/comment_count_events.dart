sealed class CommentCountEvent {}

/// Fetch the current top-level comment count (dispatched once on mount).
class CommentCountRequested extends CommentCountEvent {}
