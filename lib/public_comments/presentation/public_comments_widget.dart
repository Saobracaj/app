import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../models/public_comment.dart';
import '../state_management/comments_bloc.dart';
import '../state_management/comments_events.dart';
import '../state_management/comments_state.dart';
import 'relative_time.dart';

/// Public, social comments for one exam question (the "Дискусија" tab).
///
/// Rendered as a plain column inside the question's own scroll view (like the
/// editorial comment widget), so pagination is a "load more" affordance rather
/// than an inner scroll. Reading is open to everyone; the composer appears only
/// for a signed-in, non-banned user who has set a display name.
class PublicCommentsWidget extends StatelessWidget {
  const PublicCommentsWidget({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<CommentsBloc>(param1: questionId)..add(CommentsStarted()),
      child: BlocConsumer<CommentsBloc, CommentsState>(
        listenWhen: (prev, curr) =>
            curr.errorMessage != null && curr.errorMessage != prev.errorMessage,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
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
            child: _Composer(
              hint: 'Написать комментарий',
              submitting: state.submitting,
              onSubmit: (text) => bloc.add(CommentSubmitted(text)),
            ),
          )
        else if (state.needsDisplayName)
          const _DisplayNamePrompt()
        else if (state.isBanned)
          const _Notice('Вы не можете оставлять комментарии.'),
        if (state.comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text('Пока нет комментариев. Будьте первым!'),
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
                      child: const Text('Показать ещё'),
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
          _AuthorLine(comment: comment),
          const SizedBox(height: 4),
          Text(comment.body),
          const SizedBox(height: 4),
          Row(
            children: [
              _LikeButton(comment: comment),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showReplySheet(context, bloc),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Ответить'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Spacer(),
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
                      child: Text('Показать предыдущие ($hiddenCount)'),
                    ),
                  ...visibleReplies.map((r) => _ReplyTile(reply: r)),
                ],
              ),
            ),
          if (state.canWrite)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: _Composer(
                hint: 'Ответить',
                dense: true,
                submitting: state.submitting,
                onSubmit: (text) =>
                    bloc.add(CommentSubmitted(text, parentId: comment.id)),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  void _showReplySheet(BuildContext context, CommentsBloc bloc) {
    // Focus the thread's inline composer by expanding older replies (keeps the
    // field visible) — the composer itself lives under the replies.
    if (comment.replies.length > 3) bloc.add(RepliesExpanded(comment.id));
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
  const _AuthorLine({required this.comment});

  final PublicComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            comment.authorDisplayName.isEmpty
                ? 'Аноним'
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
        if (comment.deletableByMe) ...[
          const Spacer(),
          InkResponse(
            onTap: () => _confirmDelete(context),
            radius: 18,
            child: Icon(
              Icons.delete_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<CommentsBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
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
    final color = liked ? Colors.red : scheme.onSurfaceVariant;
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
      message: subscribed ? 'Вы подписаны на ответы' : 'Подписаться на ответы',
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

/// A text field that reveals a "Отправить" button once focused (per the spec).
/// A focus toggle is the sanctioned use of local widget state.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.hint,
    required this.onSubmit,
    this.submitting = false,
    this.dense = false,
  });

  final String hint;
  final ValueChanged<String> onSubmit;
  final bool submitting;
  final bool dense;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.submitting) return;
    widget.onSubmit(text);
    _controller.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final showSend = _focused || _controller.text.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            buildCounter: (_, {required currentLength, maxLength, required isFocused}) => null,
            inputFormatters: [LengthLimitingTextInputFormatter(1000)],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: widget.dense,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (showSend)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: widget.submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: _submit,
                    child: const Text('Отправить'),
                  ),
          ),
      ],
    );
  }
}

/// Shown to a signed-in user who has not set a display name yet: a shortcut to
/// the profile screen (the pre-comment dialog is a separate flow).
class _DisplayNamePrompt extends StatelessWidget {
  const _DisplayNamePrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Укажите отображаемое имя, чтобы комментировать.'),
          ),
          TextButton(
            onPressed: () => Routemaster.of(context).push('/displayName'),
            child: const Text('Указать'),
          ),
        ],
      ),
    );
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
