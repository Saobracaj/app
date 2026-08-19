import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../core/presentation/relative_time.dart';
import '../state_management/support_chats_bloc.dart';
import '../state_management/support_chats_events.dart';
import '../state_management/support_chats_state.dart';

/// The moderator's list of обращения: every user's conversation, newest activity
/// first, with a filter for the ones still waiting for an answer.
///
/// Opening a conversation is what marks it read — the list never does.
class SupportChatsPage extends StatelessWidget {
  const SupportChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('support.threadsTitle'.tr())),
      body: const SafeArea(child: SupportChatsContent()),
    );
  }
}

/// Список обращений с собственным [SupportChatsBloc]: строка фильтра и
/// счётчика сверху, дальше — прокручиваемый список. Без Scaffold —
/// встраивается и в отдельный экран, и в правую панель настроек на широком
/// экране (там ему нужна ограниченная высота).
class SupportChatsContent extends StatelessWidget {
  const SupportChatsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SupportChatsBloc>()..add(SupportChatsRequested()),
      child: const _SupportChatsView(),
    );
  }
}

class _SupportChatsView extends StatelessWidget {
  const _SupportChatsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportChatsBloc, SupportChatsState>(
      builder: (context, state) {
        final bloc = context.read<SupportChatsBloc>();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  FilterChip(
                    selected: state.onlyUnread,
                    label: Text('support.onlyUnread'.tr()),
                    onSelected: (value) =>
                        bloc.add(SupportChatsFilterToggled(value)),
                  ),
                  const Spacer(),
                  if (!state.loading)
                    Text(
                      'support.threadsCount'.plural(state.totalCount),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  IconButton(
                    tooltip: 'support.refresh'.tr(),
                    icon: const Icon(Icons.refresh),
                    onPressed: () => bloc.add(SupportChatsRequested()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (state) {
                SupportChatsState(loading: true) => const Center(
                  child: CircularProgressIndicator(),
                ),
                SupportChatsState(errorMessage: final String message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(message, textAlign: TextAlign.center),
                  ),
                ),
                SupportChatsState(threads: final threads)
                    when threads.isEmpty =>
                  Center(child: Text('support.noThreads'.tr())),
                _ => RefreshIndicator(
                  onRefresh: () async => bloc.add(SupportChatsRequested()),
                  child: ListView.separated(
                    itemCount: state.threads.length,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final thread = state.threads[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            thread.title.isEmpty
                                ? '?'
                                : thread.title.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          thread.title.isEmpty
                              ? 'support.unknownUser'.tr()
                              : thread.title,
                        ),
                        subtitle: Text(
                          thread.lastMessagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (thread.lastMessageAt != null)
                              Text(
                                relativeTime(thread.lastMessageAt!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (thread.unreadCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Badge(
                                  label: Text('${thread.unreadCount}'),
                                ),
                              ),
                          ],
                        ),
                        onTap: () => Routemaster.of(
                          context,
                        ).push('/support/threads/${thread.id}'),
                      );
                    },
                  ),
                ),
              },
            ),
          ],
        );
      },
    );
  }
}
