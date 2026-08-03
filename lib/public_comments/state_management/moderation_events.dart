sealed class ModerationEvent {}

/// Load the first page of the global comment feed (newest first).
class ModerationStarted extends ModerationEvent {}

/// Load the next page (triggered by scrolling near the bottom).
class ModerationLoadMore extends ModerationEvent {}

/// Delete any comment as a moderator (`moderateDeleteComment`).
class ModerationCommentDeleted extends ModerationEvent {
  ModerationCommentDeleted(this.id);
  final String id;
}

/// Ban (or unban) a user from writing comments (`moderateSetCommentBan`).
class ModerationUserBanned extends ModerationEvent {
  ModerationUserBanned(this.userId, {this.banned = true});
  final String userId;
  final bool banned;
}
