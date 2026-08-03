import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../../profile/presentation/display_name_dialog.dart';
import '../models/public_comment.dart';
import '../state_management/comments_bloc.dart';
import '../state_management/comments_events.dart';
import '../state_management/comments_state.dart';
import 'comment_composer.dart';
import 'relative_time.dart';

/// Public, social comments for one exam question (the "Дискусија" tab).
///
/// Rendered as a plain column inside the question's own scroll view (like the
/// editorial comment widget), so pagination is a "load more" affordance rather
/// than an inner scroll. Reading is open to everyone; the composer appears only
/// for a signed-in, non-banned user who has set a display name.
class PublicCommentsWidget extends StatelessWidget {
  const PublicCommentsWidget({
    super.key,
    required this.questionId,
    this.threadId,
  });

  final int questionId;

  /// Deep-link target thread (top-level comment id) to expand on open.
  final String? threadId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CommentsBloc>(param1: questionId, param2: threadId)
        ..add(CommentsStarted()),
      child: BlocConsumer<CommentsBloc, CommentsState>(
        listenWhen: (prev, curr) =>
            (curr.errorMessage != null &&
                curr.errorMessage != prev.errorMessage) ||
            (curr.subscriptionPromptFor != null &&
                curr.subscriptionPromptFor != prev.subscriptionPromptFor),
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (state.subscriptionPromptFor != null) {
            _offerSubscription(context, state.subscriptionPromptFor!);
          }
        },
        builder: (context, state) {
          if (state.loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _CommentsBody(state: state);
        },
      ),
    );
  }
}

class _CommentsBody extends StatelessWidget {
  const _CommentsBody({required this.state});

  final CommentsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CommentsBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.canWrite)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CommentComposer(
              hint: LocaleKeys.comments_write.tr(),
              submitting: state.submitting,
              onSubmit: (text) => _submitComment(context, state, text),
            ),
          )
        else if (state.isBanned)
          _Notice(LocaleKeys.comments_banned.tr()),
        if (state.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text(LocaleKeys.comments_empty.tr()),
          )
        else
          ...state.comments.map(
            (c) => _TopLevelComment(
              comment: c,
              state: state,
            ),
          ),
        if (state.hasNextPage)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: state.loadingMore
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton(
                      onPressed: () => bloc.add(CommentsLoadMore()),
                      child: Text(LocaleKeys.comments_showMore.tr()),
                    ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A top-level comment with its author line, body, actions and reply thread.
class _TopLevelComment extends StatelessWidget {
  const _TopLevelComment({required this.comment, required this.state});

  final PublicComment comment;
  final CommentsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CommentsBloc>();
    final replies = comment.replies;
    final expanded = state.expandedThreads.contains(comment.id);
    final visibleReplies = (replies.length > 3 && !expanded)
        ? replies.sublist(replies.length - 3)
        : replies;
    final hiddenCount = replies.length - visibleReplies.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delete for a top-level comment lives in the actions row below (next
          // to the subscribe toggle), not on the author line.
          _AuthorLine(comment: comment, showDelete: false),
          const SizedBox(height: 4),
          Text(comment.body),
          const SizedBox(height: 4),
          Row(
            children: [
              _LikeButton(comment: comment),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => bloc.add(ReplyFocusRequested(comment.id)),
                icon: const Icon(Icons.reply, size: 18),
                label: Text(LocaleKeys.comments_reply.tr()),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Spacer(),
              if (comment.deletableByMe)
                _DeleteButton(comment: comment),
              if (state.isAuthenticated)
                _SubscriptionToggle(comment: comment),
            ],
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hiddenCount > 0)
                    TextButton(
                      onPressed: () =>
                          bloc.add(RepliesExpanded(comment.id)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        LocaleKeys.comments_showPrevious
                            .tr(args: ['$hiddenCount']),
                      ),
                    ),
                  ...visibleReplies.map((r) => _ReplyTile(reply: r)),
                ],
              ),
            ),
          if (state.canWrite)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: CommentComposer(
                hint: LocaleKeys.comments_reply.tr(),
                dense: true,
                submitting: state.submitting,
                // Focus this composer when the user taps "Ответить" on this
                // top-level comment.
                focusRequestId: state.replyFocusTarget == comment.id
                    ? state.replyFocusRequestId
                    : null,
                onSubmit: (text) =>
                    _submitComment(context, state, text, parentId: comment.id),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

/// A second-level reply: author line, body, and a compact like control.
class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply});

  final PublicComment reply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorLine(comment: reply),
          const SizedBox(height: 2),
          Text(reply.body),
          const SizedBox(height: 2),
          _LikeButton(comment: reply, compact: true),
        ],
      ),
    );
  }
}

/// Display name + relative time, with a delete affordance for the caller's own
/// comments (and for moderators).
class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.comment, this.showDelete = true});

  final PublicComment comment;

  /// Whether to render the inline delete affordance on this line. Top-level
  /// comments set this to `false` — their delete control lives in the actions
  /// row instead (next to the subscribe toggle).
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            comment.authorDisplayName.isEmpty
                ? LocaleKeys.comments_anonymous.tr()
                : comment.authorDisplayName,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          relativeTime(comment.createdAt),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (showDelete && comment.deletableByMe) ...[
          const Spacer(),
          _DeleteButton(comment: comment),
        ],
      ],
    );
  }
}

/// Delete affordance for a comment the caller may remove (their own, or any
/// comment for a moderator). Confirms before dispatching the delete.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.comment});

  final PublicComment comment;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () => _confirmDelete(context),
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.delete_outline,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<CommentsBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.comments_deleteTitle.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocaleKeys.comments_cancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocaleKeys.comments_delete.tr()),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(CommentDeleted(comment.id));
  }
}

/// Heart + count. The count is toggled optimistically in the Bloc; here the
/// heart fill and the count animate on change.
class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.comment, this.compact = false});

  final PublicComment comment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liked = comment.likedByMe;
    // Use the theme's palette (accent) for the "liked" state rather than a
    // hardcoded red, so likes follow the app's colour scheme.
    final color = liked ? scheme.primary : scheme.onSurfaceVariant;
    return InkResponse(
      onTap: () => context.read<CommentsBloc>().add(CommentLikeToggled(comment)),
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(liked),
                size: compact ? 16 : 18,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axis: Axis.horizontal,
                  child: child,
                ),
              ),
              child: Text(
                '${comment.likesCount}',
                key: ValueKey(comment.likesCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: liked ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimalist per-thread reply-subscription toggle (top-level comments only).
class _SubscriptionToggle extends StatelessWidget {
  const _SubscriptionToggle({required this.comment});

  final PublicComment comment;

  @override
  Widget build(BuildContext context) {
    final subscribed = comment.subscribedByMe;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: subscribed
          ? LocaleKeys.comments_subscribedTooltip.tr()
          : LocaleKeys.comments_subscribeTooltip.tr(),
      child: InkResponse(
        radius: 20,
        onTap: () => context
            .read<CommentsBloc>()
            .add(CommentSubscriptionToggled(comment, !subscribed)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            subscribed
                ? Icons.notifications_active
                : Icons.notifications_none,
            size: 18,
            color: subscribed ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Submit a top-level comment or reply. If the signed-in user has no display
/// name yet, a dialog collects one first (a comment may not be posted without
/// it); the name is persisted by the Bloc alongside the post. Returns `false`
/// when the flow was cancelled so the composer keeps the user's text.
Future<bool> _submitComment(
  BuildContext context,
  CommentsState state,
  String text, {
  String? parentId,
}) async {
  final bloc = context.read<CommentsBloc>();
  String? displayNameToSet;
  if (state.mustPromptDisplayName) {
    final name = await showDisplayNameDialog(context);
    if (name == null) return false; // cancelled — keep the typed text
    displayNameToSet = name;
  }
  bloc.add(
    CommentSubmitted(
      text,
      parentId: parentId,
      displayNameToSet: displayNameToSet,
    ),
  );
  return true;
}

/// After a successful post, offer to subscribe to replies. Accepting delegates
/// the push-permission/enable + subscribe flow to the Bloc; declining just
/// clears the prompt.
Future<void> _offerSubscription(
  BuildContext context,
  PublicComment comment,
) async {
  final bloc = context.read<CommentsBloc>();
  final agreed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(LocaleKeys.comments_subscribeTitle.tr()),
      content: Text(LocaleKeys.comments_subscribeBody.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(LocaleKeys.comments_subscribeNotNow.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(LocaleKeys.comments_subscribe.tr()),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (agreed == true) {
    bloc.add(CommentSubscribeAccepted(comment));
  } else {
    bloc.add(SubscriptionPromptDismissed());
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
