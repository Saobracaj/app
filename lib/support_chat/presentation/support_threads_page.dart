import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../public_comments/presentation/relative_time.dart';
import '../state_management/support_threads_bloc.dart';
import '../state_management/support_threads_events.dart';
import '../state_management/support_threads_state.dart';

/// The moderator's list of обращения: every user's conversation, newest activity
/// first, with a filter for the ones still waiting for an answer.
///
/// Opening a conversation is what marks it read — the list never does.
class SupportThreadsPage extends StatelessWidget {
  const SupportThreadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<SupportThreadsBloc>()..add(SupportThreadsRequested()),
      child: const _SupportThreadsView(),
    );
  }
}

class _SupportThreadsView extends StatelessWidget {
  const _SupportThreadsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportThreadsBloc, SupportThreadsState>(
      builder: (context, state) {
        final bloc = context.read<SupportThreadsBloc>();
        return Scaffold(
          appBar: AppBar(
            title: Text('support.threadsTitle'.tr()),
            actions: [
              IconButton(
                tooltip: 'support.refresh'.tr(),
                icon: const Icon(Icons.refresh),
                onPressed: () => bloc.add(SupportThreadsRequested()),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    FilterChip(
                      selected: state.onlyUnread,
                      label: Text('support.onlyUnread'.tr()),
                      onSelected: (value) =>
                          bloc.add(SupportThreadsFilterToggled(value)),
                    ),
                    const Spacer(),
                    if (!state.loading)
                      Text(
                        'support.threadsCount'.plural(state.totalCount),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: switch (state) {
              SupportThreadsState(loading: true) => const Center(
                child: CircularProgressIndicator(),
              ),
              SupportThreadsState(errorMessage: final String message) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              ),
              SupportThreadsState(threads: final threads) when threads.isEmpty =>
                Center(child: Text('support.noThreads'.tr())),
              _ => RefreshIndicator(
                onRefresh: () async => bloc.add(SupportThreadsRequested()),
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
        );
      },
    );
  }
}
