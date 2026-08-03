import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
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
      appBar: AppBar(title: const Text('Модерация комментариев')),
      body: SafeArea(
        child: BlocProvider(
          create: (_) => getIt<ModerationBloc>()..add(ModerationStarted()),
          child: const _ModerationView(),
        ),
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
      },
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.comments.isEmpty) {
          return const Center(child: Text('Комментариев пока нет.'));
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
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(comment.body),
          const SizedBox(height: 4),
          Text(
            'Вопрос №${comment.questionId}'
            '${comment.parentId != null ? ' · ответ' : ''}'
            ' · ♥ ${comment.likesCount}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _onAction(context, value),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'question', child: Text('Перейти к вопросу')),
          PopupMenuItem(value: 'delete', child: Text('Удалить комментарий')),
          PopupMenuItem(value: 'ban', child: Text('Запретить пользователю')),
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
          title: 'Удалить комментарий?',
          action: 'Удалить',
        );
        if (ok) bloc.add(ModerationCommentDeleted(comment.id));
      case 'ban':
        final ok = await _confirm(
          context,
          title: 'Запретить пользователю комментировать?',
          action: 'Запретить',
        );
        if (ok && comment.authorId.isNotEmpty) {
          bloc.add(ModerationUserBanned(comment.authorId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Пользователю запрещено комментировать.')),
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
            child: const Text('Отмена'),
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
