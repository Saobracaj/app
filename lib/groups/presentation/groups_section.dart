import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/presentation/wide_layout.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/presentation/feature_gate.dart';
import '../../generated/locale_keys.g.dart';
import '../../public_comments/presentation/relative_time.dart';
import '../models/group.dart';
import '../models/group_event.dart' show groupEventIsWorthShowing;
import '../state_management/groups_bloc.dart';
import '../state_management/groups_events.dart';
import '../state_management/groups_state.dart';
import 'group_dialogs.dart';
import 'group_event_summary.dart';

/// The "groups" block of the home screen: one card per group the user belongs
/// to, plus the two entry points — create a group, or join one with a code.
///
/// Gated on the `groups` flag, which is an authenticated-tier feature, so the
/// whole block is invisible to a signed-out user (and to anyone who turned the
/// feature off in settings).
class GroupsSection extends StatelessWidget {
  const GroupsSection({super.key, this.wide = false});

  /// Раскладка широкого экрана: карточки групп сеткой, а «создать группу» —
  /// карточкой-приглашением рядом с ними (макет веб-версии).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: AppFeature.groups,
      child: _GroupsSectionBody(wide: wide),
    );
  }
}

class _GroupsSectionBody extends StatelessWidget {
  const _GroupsSectionBody({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupsBloc, GroupsState>(
      listenWhen: (prev, curr) =>
          curr.openGroupId != null || curr.invitePreview != null,
      listener: (context, state) {
        final preview = state.invitePreview;
        final token = state.previewToken;
        if (preview != null && token != null) {
          // The code resolved: show whose group it is and ask before joining.
          context.read<GroupsBloc>().add(const GroupInvitePreviewHandled());
          confirmInviteFlow(context, preview, token);
          return;
        }
        // A freshly created or joined group opens straight away — on its feed,
        // like the card; the owner reaches the invite from the feed's menu.
        final id = state.openGroupId;
        context.read<GroupsBloc>().add(const GroupOpenHandled());
        if (id != null) Routemaster.of(context).push('/groups/$id/feed');
      },
      builder: (context, state) {
        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                title: LocaleKeys.groups_section.tr(),
                // Обе точки входа стоят рядом в шапке раздела: «создать» —
                // основное действие, «войти по коду» — рядом с ним.
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: state.busy
                          ? null
                          : () => createGroupFlow(context),
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(LocaleKeys.groups_create.tr()),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: state.busy
                          ? null
                          : () => joinGroupFlow(context),
                      child: Text(LocaleKeys.groups_join.tr()),
                    ),
                  ],
                ),
              ),
              if (state.loading && !state.loaded)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              // Кнопка «создать» уехала в шапку раздела, поэтому пустой сетке
              // нужна своя подсказка — иначе раздел выглядит сломанным.
              if (state.isEmpty)
                Text(
                  LocaleKeys.groups_empty.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ResponsiveGrid(
                  minItemWidth: 340,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final group in state.groups) GroupCard(group: group),
                  ],
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                LocaleKeys.groups_section.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (state.loading && !state.loaded)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (state.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  LocaleKeys.groups_empty.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            for (final group in state.groups)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: GroupCard(group: group),
              ),
            _GroupActions(busy: state.busy),
          ],
        );
      },
    );
  }
}

/// The create/join pair under the cards.
class _GroupActions extends StatelessWidget {
  const _GroupActions({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: busy ? null : () => createGroupFlow(context),
            icon: const Icon(Icons.group_add_outlined),
            label: Text(LocaleKeys.groups_create.tr()),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: busy ? null : () => joinGroupFlow(context),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(LocaleKeys.groups_join.tr()),
          ),
        ],
      ),
    );
  }
}

/// One group on the home screen: its name, how many people are in it and the
/// last few things that happened, or a line saying nothing has yet. Tapping it
/// opens the group.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = group.feedPreview.where(groupEventIsWorthShowing).toList();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Карточка ведёт сразу в ленту событий; управление группой (участники,
        // приглашение) — в меню на экране ленты.
        onTap: () => Routemaster.of(context).push('/groups/${group.id}/feed'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    LocaleKeys.groups_membersCount.tr(
                      args: ['${group.memberCount}'],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (events.isEmpty)
                Text(
                  LocaleKeys.groups_noEvents.tr(),
                  style: theme.textTheme.bodySmall,
                )
              else
                for (final event in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            groupEventSummary(context, event),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          relativeTime(event.occurredAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
              // "See everything that happened" — the full feed, which pages
              // through the history and keeps itself up to date while open.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () =>
                      Routemaster.of(context).push('/groups/${group.id}/feed'),
                  child: Text(LocaleKeys.groups_openFeed.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
