import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/state_management/network_status_bloc.dart';
import '../../core/presentation/load_failed_view.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/presentation/feature_gate.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/groups_bloc.dart';
import '../state_management/groups_events.dart';
import '../state_management/groups_state.dart';
import 'group_dialogs.dart';
import 'groups_section.dart' show GroupCard;

/// Раздел настроек «Группы»: обе точки входа (создать группу, войти по коду) и
/// список групп пользователя.
///
/// Группами пока почти не пользуются, поэтому управление ими живёт здесь, а не
/// на главной: главная показывает только сами группы, и только если они есть
/// ([GroupsSection]).
class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.groups_section.tr())),
      body: SafeArea(
        child: ListView(
          children: const [GroupsContent(), SizedBox(height: 24)],
        ),
      ),
    );
  }
}

/// Содержимое раздела без собственного скролла и Scaffold — встраивается и в
/// отдельный экран, и в правую панель настроек на широком экране.
class GroupsContent extends StatelessWidget {
  const GroupsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: AppFeature.groups,
      child: BlocBuilder<GroupsBloc, GroupsState>(
        builder: (context, state) {
          // Не загрузившийся список показывает «повторить» прямо в разделе —
          // кроме случая, когда связи нет вовсе: тогда список перечитается сам,
          // как только она появится.
          final online = context.select<NetworkStatusBloc, bool>(
            (bloc) => bloc.state.online,
          );
          final showLoadFailed = state.failed && !state.loaded && online;
          final theme = Theme.of(context);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  LocaleKeys.groups_createHint.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: state.busy
                          ? null
                          : () => createGroupFlow(context),
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(LocaleKeys.groups_create.tr()),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: state.busy
                          ? null
                          : () => joinGroupFlow(context),
                      icon: const Icon(Icons.qr_code_2_outlined),
                      label: Text(LocaleKeys.groups_join.tr()),
                    ),
                  ],
                ),
              ),
              if (state.loading && !state.loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (showLoadFailed)
                LoadFailedView(
                  compact: true,
                  onRetry: () =>
                      context.read<GroupsBloc>().add(const GroupsRefreshed()),
                ),
              if (state.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    LocaleKeys.groups_empty.tr(),
                    style: theme.textTheme.bodyMedium,
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
      ),
    );
  }
}
