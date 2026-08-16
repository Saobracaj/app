import '../../question_lists/models/question_list.dart';

/// What can happen on a group's wall: the reader scrolling, and the author
/// composing.
sealed class GroupPostsBlocEvent {
  const GroupPostsBlocEvent();
}

/// The tab opened: load the newest page.
class GroupPostsOpened extends GroupPostsBlocEvent {
  const GroupPostsOpened();
}

/// Pull-to-refresh, and what the feed subscription triggers when somebody else
/// posts: re-read the newest page.
class GroupPostsRefreshed extends GroupPostsBlocEvent {
  const GroupPostsRefreshed();
}

/// The reader reached the bottom: load the page behind the cursor.
class GroupPostsMoreRequested extends GroupPostsBlocEvent {
  const GroupPostsMoreRequested();
}

/// The paperclip: pick a file or an image and upload it right away, so it is
/// ready by the time the post is sent.
class GroupPostAttachPressed extends GroupPostsBlocEvent {
  const GroupPostAttachPressed();
}

/// One of the question lists the author picked, to be shared as a chip.
class GroupPostListAttached extends GroupPostsBlocEvent {
  const GroupPostListAttached(this.list);

  final QuestionList list;
}

/// Take an attachment off the composer before the post is sent. Uploaded files
/// are identified by their attachment id, shared lists by the list's id.
class GroupPostAttachmentRemoved extends GroupPostsBlocEvent {
  const GroupPostAttachmentRemoved(this.id);

  final String id;
}

/// The author typed. The text lives in the Bloc, so the send button and the
/// composer agree on whether there is anything to send.
class GroupPostBodyChanged extends GroupPostsBlocEvent {
  const GroupPostBodyChanged(this.body);

  final String body;
}

/// Publish what the composer holds.
class GroupPostSubmitted extends GroupPostsBlocEvent {
  const GroupPostSubmitted();
}

/// Delete a post — its author, or the group's owner.
class GroupPostDeleted extends GroupPostsBlocEvent {
  const GroupPostDeleted(this.postId);

  final String postId;
}

/// A comment was written or removed under [postId]: the count on the card is
/// stale, so re-read it.
class GroupPostCommentsChanged extends GroupPostsBlocEvent {
  const GroupPostCommentsChanged(this.postId, this.delta);

  final String postId;

  /// `+1` for a new comment, `-1` for a deleted one.
  final int delta;
}

/// The error message was shown; clear it.
class GroupPostsErrorShown extends GroupPostsBlocEvent {
  const GroupPostsErrorShown();
}
