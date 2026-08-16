import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../models/public_comment.dart';
import '../state_management/moderation_bloc.dart';
import '../state_management/moderation_events.dart';
import '../state_management/moderation_state.dart';
import 'relative_time.dart';

/// Moderation screen (settings › «Модерация комментариев»), shown only to users
/// with the `moderate_comments` permission. Lists every comment newest-first
/// with scroll pagination; each row can jump to the source question, delete the
/// comment, or ban its author from commenting.
class ModerationPage extends StatelessWidget {
  const ModerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.comments_moderation_title.tr())),
      body: const SafeArea(child: ModerationContent()),
    );
  }
}

/// Лента модерации с собственным [ModerationBloc] и внутренним скроллом
/// (пагинация), но без Scaffold — встраивается и в отдельный экран, и в правую
/// панель настроек на широком экране (там ей нужна ограниченная высота).
class ModerationContent extends StatelessWidget {
  const ModerationContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ModerationBloc>()..add(ModerationStarted()),
      child: const _ModerationView(),
    );
  }
}

class _ModerationView extends StatelessWidget {
  const _ModerationView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ModerationBloc, ModerationState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.comments.isEmpty) {
          return Center(child: Text(LocaleKeys.comments_moderation_empty.tr()));
        }
        final bloc = context.read<ModerationBloc>();
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 300 &&
                state.hasNextPage &&
                !state.loadingMore) {
              bloc.add(ModerationLoadMore());
            }
            return false;
          },
          child: ListView.separated(
            itemCount: state.comments.length + (state.hasNextPage ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemBuilder: (context, index) {
              if (index >= state.comments.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _ModerationTile(comment: state.comments[index]);
            },
          ),
        );
      },
    );
  }
}

class _ModerationTile extends StatelessWidget {
  const _ModerationTile({required this.comment});

  final PublicComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      isThreeLine: true,
      title: Row(
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
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(comment.displayBody),
          const SizedBox(height: 4),
          Text(
            '${LocaleKeys.comments_moderation_questionLabel.tr(args: ['${comment.questionId}'])}'
            '${comment.parentId != null ? ' · ${LocaleKeys.comments_moderation_replyLabel.tr()}' : ''}'
            ' · ♥ ${comment.likesCount}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _onAction(context, value),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'question',
            child: Text(LocaleKeys.comments_moderation_goToQuestion.tr()),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(LocaleKeys.comments_moderation_deleteComment.tr()),
          ),
          PopupMenuItem(
            value: 'ban',
            child: Text(LocaleKeys.comments_moderation_banUser.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String value) async {
    final bloc = context.read<ModerationBloc>();
    switch (value) {
      case 'question':
        Routemaster.of(context).push('/quest?q=${comment.questionId}');
      case 'delete':
        final ok = await _confirm(
          context,
          title: LocaleKeys.comments_moderation_deleteTitle.tr(),
          action: LocaleKeys.comments_moderation_deleteComment.tr(),
        );
        if (ok) bloc.add(ModerationCommentDeleted(comment.id));
      case 'ban':
        final ok = await _confirm(
          context,
          title: LocaleKeys.comments_moderation_banTitle.tr(),
          action: LocaleKeys.comments_moderation_banAction.tr(),
        );
        if (ok && comment.authorId.isNotEmpty) {
          bloc.add(ModerationUserBanned(comment.authorId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocaleKeys.comments_moderation_banned.tr()),
              ),
            );
          }
        }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocaleKeys.comments_cancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }
}
