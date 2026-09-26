import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/presentation/wide_layout.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/presentation/feature_gate.dart';
import '../../generated/locale_keys.g.dart';
import '../../core/presentation/relative_time.dart';
import '../models/group.dart';
import '../models/group_event.dart' show groupEventIsWorthShowing;
import '../state_management/groups_bloc.dart';
import '../state_management/groups_state.dart';
import 'group_event_summary.dart';

/// The "groups" block of the home screen: one card per group the user belongs
/// to — and nothing at all when there are none.
///
/// Группами пока почти никто не пользуется, поэтому места на главной они
/// занимают ровно столько, сколько заслужили: ни заголовка, ни приглашения
/// создать группу у того, кто ни в одной не состоит. Сами точки входа
/// (создать, войти по коду) живут в разделе настроек «Группы»
/// (`GroupsContent`), а подтверждение приглашения и открытие новой группы — в
/// `GroupsFlowListener` над вкладками.
///
/// Gated on the `groups` flag, which is an authenticated-tier feature, so the
/// whole block is invisible to a signed-out user (and to anyone who turned the
/// feature off in settings).
class GroupsSection extends StatelessWidget {
  const GroupsSection({super.key, this.wide = false});

  /// Раскладка широкого экрана: карточки групп сеткой (макет веб-версии).
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
    return BlocBuilder<GroupsBloc, GroupsState>(
      // Состояния загрузки и ошибки на главной не показываются: раздел здесь —
      // просто список групп, а разбираться с неудачной загрузкой есть где
      // (настройки → «Группы»).
      buildWhen: (prev, curr) => prev.groups != curr.groups,
      builder: (context, state) {
        if (state.groups.isEmpty) return const SizedBox.shrink();

        // Отступ от секции выше живёт здесь, а не на главной: пустая секция не
        // должна оставлять после себя дырку.
        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 38),
              SectionHeading(title: LocaleKeys.groups_section.tr()),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                LocaleKeys.groups_section.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final group in state.groups)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: GroupCard(group: group),
              ),
          ],
        );
      },
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
                  // Непрочитанное в чате группы: значок рядом с числом
                  // участников, чтобы новое сообщение было видно с главной.
                  if (group.chatUnreadCount > 0) ...[
                    Badge.count(
                      count: group.chatUnreadCount,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.forum_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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
