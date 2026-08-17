import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../core/presentation/load_failed_view.dart';
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
/// Laid out the way social feeds do it, so nothing important hides behind a
/// long-press: avatar on the left, author + time above the body, and a visible
/// action row (like, "Ответить") below it; the rarer actions — report, thread
/// subscription, copy, delete — sit behind the "⋯" button on every row (a
/// long-press opens the same menu as a shortcut). One composer is pinned at
/// the bottom of the section; replying targets it via a chip. Rendered as a
/// plain column inside the question's own scroll view, so pagination is a
/// "load more" affordance rather than an inner scroll. Reading is open to
/// everyone.
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
      create: (_) =>
          getIt<CommentsBloc>(param1: questionId, param2: threadId)
            ..add(CommentsStarted()),
      child: BlocConsumer<CommentsBloc, CommentsState>(
        listenWhen: (prev, curr) =>
            (curr.errorMessage != null &&
                curr.errorMessage != prev.errorMessage) ||
            (curr.subscriptionPromptFor != null &&
                curr.subscriptionPromptFor != prev.subscriptionPromptFor),
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
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
          if (state.failed) {
            // "No network" / "couldn't load" with a retry, in place of the
            // list — a failed load must not look like "no comments yet". The
            // Bloc also reloads on its own once the connection is back.
            return LoadFailedView(
              compact: true,
              offline: state.failedOffline,
              message: state.failedOffline
                  ? LocaleKeys.network_noConnection.tr()
                  : LocaleKeys.comments_loadError.tr(),
              onRetry: () =>
                  context.read<CommentsBloc>().add(CommentsRefreshed()),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
            child: Text(LocaleKeys.comments_empty.tr()),
          )
        else
          // The ink of the row highlights would otherwise be swallowed by the
          // feature card's background color painted above the nearest Material.
          Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < state.comments.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _Thread(comment: state.comments[i], state: state),
                ],
              ],
            ),
          ),
        if (state.hasNextPage)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        if (state.canWrite || state.isBanned) ...[
          if (state.comments.isNotEmpty) const Divider(height: 1),
          if (state.canWrite)
            _ComposerSection(state: state)
          else
            _Notice(LocaleKeys.comments_banned.tr()),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A top-level comment with its (collapsed) reply thread.
class _Thread extends StatelessWidget {
  const _Thread({required this.comment, required this.state});

  final PublicComment comment;
  final CommentsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CommentsBloc>();
    final replies = comment.replies;
    final expanded = state.expandedThreads.contains(comment.id);
    // Collapsed threads show only the most recent reply (decision 11).
    final visibleReplies = (replies.length > 1 && !expanded)
        ? [replies.last]
        : replies;
    final hiddenCount = replies.length - visibleReplies.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTile(comment: comment, state: state),
          if (hiddenCount > 0)
            Padding(
              // Aligned with the replies' column, under the parent's text.
              padding: const EdgeInsets.only(left: 42),
              child: TextButton(
                onPressed: () => bloc.add(RepliesExpanded(comment.id)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  LocaleKeys.comments_showPrevious.tr(args: ['$hiddenCount']),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          for (final reply in visibleReplies)
            Padding(
              // The smaller avatar carries the "this is a reply" signal, so no
              // thread line is needed.
              padding: const EdgeInsets.only(left: 42, top: 2),
              child: _CommentTile(comment: reply, state: state, isReply: true),
            ),
        ],
      ),
    );
  }
}

/// What the "⋯" / long-press menu can do with a comment. Reply and like are
/// not here — they are visible on the row itself.
enum _CommentAction { report, subscribe, copy, delete }

/// One comment row, social-feed style: avatar, author + time with the "⋯"
/// menu button on the far right, the body, and a visible action row (like,
/// reply). A long-press anywhere on the row opens the same menu as "⋯"; the
/// only widget state is the last press position, needed to anchor that menu
/// at the finger (the sanctioned purely-visual exception).
class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.state,
    this.isReply = false,
  });

  final PublicComment comment;
  final CommentsState state;

  /// Replies are drawn with a smaller avatar under their parent.
  final bool isReply;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  Offset _pressPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = widget.comment;
    final bloc = context.read<CommentsBloc>();
    final topLevelId = comment.parentId ?? comment.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTapDown: (details) => _pressPosition = details.globalPosition,
      onLongPress: () => _showActionsMenu(context, _pressPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(
              displayName: comment.authorDisplayName,
              size: widget.isReply ? 26 : 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _AuthorLine(comment: comment)),
                      // Anchors the shared actions menu right under itself.
                      Builder(
                        builder: (buttonContext) => InkResponse(
                          radius: 16,
                          onTap: () {
                            final box =
                                buttonContext.findRenderObject()! as RenderBox;
                            _showActionsMenu(
                              context,
                              box.localToGlobal(
                                Offset(box.size.width, box.size.height),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    comment.displayBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontStyle: comment.isDeleted ? FontStyle.italic : null,
                      color: comment.isDeleted
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _LikeButton(comment: comment),
                      if (widget.state.canWrite) ...[
                        const SizedBox(width: 14),
                        InkResponse(
                          radius: 20,
                          onTap: () =>
                              bloc.add(ReplyFocusRequested(topLevelId)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Text(
                              LocaleKeys.comments_reply.tr(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActionsMenu(BuildContext context, Offset anchor) async {
    final bloc = context.read<CommentsBloc>();
    final state = widget.state;
    final comment = widget.comment;
    final topLevelId = comment.parentId ?? comment.id;
    final top = state.comments.firstWhereOrNull((c) => c.id == topLevelId);
    // Both ids default to '' — without the isNotEmpty guard every
    // anonymous-author comment would look like the viewer's own.
    final isOwn =
        comment.authorId.isNotEmpty && comment.authorId == state.viewerId;
    final reported = state.reportedIds.contains(comment.id);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    final action = await showMenu<_CommentAction>(
      context: context,
      position: RelativeRect.fromRect(
        anchor & Size.zero,
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      items: [
        if (state.isAuthenticated && !isOwn)
          reported
              ? _menuItem(
                  null,
                  Icons.flag_outlined,
                  LocaleKeys.comments_reported.tr(),
                  enabled: false,
                )
              : _menuItem(
                  _CommentAction.report,
                  Icons.flag_outlined,
                  LocaleKeys.comments_report.tr(),
                ),
        if (state.isAuthenticated && top != null)
          _menuItem(
            _CommentAction.subscribe,
            top.subscribedByMe
                ? Icons.notifications_off_outlined
                : Icons.notifications_none,
            top.subscribedByMe
                ? LocaleKeys.comments_unsubscribe.tr()
                : LocaleKeys.comments_subscribeThread.tr(),
          ),
        _menuItem(
          _CommentAction.copy,
          Icons.copy_outlined,
          LocaleKeys.comments_copy.tr(),
        ),
        if (comment.deletableByMe)
          _menuItem(
            _CommentAction.delete,
            Icons.delete_outline,
            LocaleKeys.comments_delete.tr(),
          ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _CommentAction.report:
        await _confirmReport(context, bloc, comment);
      case _CommentAction.subscribe:
        bloc.add(CommentSubscriptionToggled(top!, !top.subscribedByMe));
      case _CommentAction.copy:
        await Clipboard.setData(ClipboardData(text: comment.displayBody));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleKeys.comments_copied.tr())),
          );
        }
      case _CommentAction.delete:
        await _confirmDelete(context, bloc, comment);
    }
  }

  PopupMenuItem<_CommentAction> _menuItem(
    _CommentAction? value,
    IconData icon,
    String label, {
    bool enabled = true,
  }) {
    return PopupMenuItem<_CommentAction>(
      value: value,
      enabled: enabled,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

/// Report flow. UI-only while the backend has no reportComment mutation: the
/// confirmation and the "sent" acknowledgement work, the id is remembered for
/// the session so the menu shows the comment as already reported.
Future<void> _confirmReport(
  BuildContext context,
  CommentsBloc bloc,
  PublicComment comment,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(LocaleKeys.comments_reportTitle.tr()),
      content: Text(LocaleKeys.comments_reportBody.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(LocaleKeys.comments_cancel.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(LocaleKeys.comments_report.tr()),
        ),
      ],
    ),
  );
  if (ok != true) return;
  bloc.add(CommentReported(comment.id));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LocaleKeys.comments_reported.tr())));
  }
}

/// Confirm and dispatch the deletion of [comment] (the caller's own, or any
/// comment for a moderator).
Future<void> _confirmDelete(
  BuildContext context,
  CommentsBloc bloc,
  PublicComment comment,
) async {
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

/// Display name + relative time, aligned on the text baseline.
class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.comment});

  final PublicComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            comment.authorDisplayName.isEmpty
                ? LocaleKeys.comments_anonymous.tr()
                : comment.authorDisplayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          relativeTime(comment.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Heart + count. The count is toggled optimistically in the Bloc; here the
/// heart fill and the count animate on change.
class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.comment});

  final PublicComment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liked = comment.likedByMe;
    // Use the theme's palette (accent) for the "liked" state rather than a
    // hardcoded red, so likes follow the app's colour scheme.
    final color = liked ? scheme.primary : scheme.onSurfaceVariant;
    return InkResponse(
      onTap: () =>
          context.read<CommentsBloc>().add(CommentLikeToggled(comment)),
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
                size: 18,
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

/// The single pinned composer at the bottom of the section: avatar, the reply
/// target chip (when set from the menu) and the input field.
class _ComposerSection extends StatelessWidget {
  const _ComposerSection({required this.state});

  final CommentsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CommentsBloc>();
    final target = state.replyFocusTarget == null
        ? null
        : state.comments.firstWhereOrNull(
            (c) => c.id == state.replyFocusTarget,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (target != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: InputChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                LocaleKeys.comments_replyingTo.tr(
                  args: [
                    target.authorDisplayName.isEmpty
                        ? LocaleKeys.comments_anonymous.tr()
                        : target.authorDisplayName,
                  ],
                ),
              ),
              onDeleted: () => bloc.add(ReplyTargetCleared()),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(displayName: state.profile?.displayName),
              const SizedBox(width: 10),
              Expanded(
                child: CommentComposer(
                  hint: LocaleKeys.comments_write.tr(),
                  submitting: state.submitting,
                  // Focus the field when a reply target was just chosen.
                  focusRequestId: state.replyFocusTarget != null
                      ? state.replyFocusRequestId
                      : null,
                  onSubmit: (text) => _submitComment(
                    context,
                    state,
                    text,
                    parentId: state.replyFocusTarget,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The initials circle: next to the composer and on every comment row.
///
/// The background is picked from the scheme's container colours by a stable
/// hash of the name, so different authors read apart at a glance while staying
/// inside the app's palette. Anonymous (or empty) names get the neutral circle
/// with a person icon.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.displayName, this.size = 34});

  final String? displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = (displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2);
    final initials = words.map((w) => w[0].toUpperCase()).join();
    final palette = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    // String.hashCode is not stable across runs; a code-unit sum is.
    final hash = (displayName ?? '').codeUnits.fold<int>(
      0,
      (sum, unit) => sum + unit,
    );
    final (background, foreground) = initials.isEmpty
        ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
        : palette[hash % palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: initials.isEmpty
          ? Icon(Icons.person_outline, size: size * 0.55, color: foreground)
          : Text(
              initials,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: size * 0.38,
                color: foreground,
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
