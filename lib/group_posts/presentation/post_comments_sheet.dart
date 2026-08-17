import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../core/presentation/load_failed_view.dart';
import '../../generated/locale_keys.g.dart';
import '../../public_comments/presentation/relative_time.dart';
import '../models/group_post.dart';
import '../state_management/group_posts_bloc.dart';
import '../state_management/group_posts_events.dart';
import '../state_management/post_comments_bloc.dart';
import '../state_management/post_comments_events.dart';
import '../state_management/post_comments_state.dart';

/// The discussion under one post, in a sheet over the wall.
///
/// The wall's Bloc is handed down rather than looked up inside: a modal sheet is
/// pushed on the root navigator and does not inherit the tab's providers, and
/// the count on the card has to move when somebody comments here.
Future<void> showPostComments(BuildContext context, GroupPost post) {
  final wall = context.read<GroupPostsBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: BlocProvider(
        create: (_) =>
            getIt<PostCommentsBloc>(param1: post.id)
              ..add(const PostCommentsLoaded()),
        child: _CommentsSheet(post: post, wall: wall),
      ),
    ),
  );
}

class _CommentsSheet extends StatelessWidget {
  const _CommentsSheet({required this.post, required this.wall});

  final GroupPost post;
  final GroupPostsBloc wall;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PostCommentsBloc, PostCommentsState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        context.read<PostCommentsBloc>().add(const PostCommentsErrorShown());
      },
      builder: (context, state) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                child: Text(
                  LocaleKeys.groups_posts_commentsTitle.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: switch ((state.loaded, state.failed, state.isEmpty)) {
                  // Прочитать не удалось: раньше здесь навсегда оставался
                  // индикатор, а объяснение уезжало со снек-баром.
                  (false, true, _) => LoadFailedView(
                    offline: state.failedOffline,
                    message: state.failedOffline
                        ? LocaleKeys.network_noConnection.tr()
                        : null,
                    onRetry: () => context.read<PostCommentsBloc>().add(
                      const PostCommentsLoaded(),
                    ),
                  ),
                  (false, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  (_, _, true) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(LocaleKeys.groups_posts_noComments.tr()),
                    ),
                  ),
                  _ => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final comment in state.comments)
                        _CommentTile(comment: comment, wall: wall),
                    ],
                  ),
                },
              ),
              _CommentField(postId: post.id, wall: wall),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.wall});

  final GroupPostComment comment;
  final GroupPostsBloc wall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Row(
        children: [
          Flexible(
            child: Text(
              comment.authorDisplayName,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime(comment.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      subtitle: Text(comment.body),
      trailing: comment.deletableByMe
          ? IconButton(
              tooltip: LocaleKeys.groups_posts_delete.tr(),
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                context.read<PostCommentsBloc>().add(
                  PostCommentDeleted(comment.id),
                );
                wall.add(GroupPostCommentsChanged(comment.postId, -1));
              },
            )
          : null,
    );
  }
}

/// Writing a comment. Stateful only to own its controller, like the wall's own
/// composer field.
class _CommentField extends StatefulWidget {
  const _CommentField({required this.postId, required this.wall});

  final String postId;
  final GroupPostsBloc wall;

  @override
  State<_CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<_CommentField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(BuildContext context) {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    context.read<PostCommentsBloc>().add(PostCommentSubmitted(body));
    widget.wall.add(GroupPostCommentsChanged(widget.postId, 1));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.select<PostCommentsBloc, bool>(
      (bloc) => bloc.state.submitting,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: LocaleKeys.groups_posts_commentHint.tr(),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: submitting ? null : () => _send(context),
            icon: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
