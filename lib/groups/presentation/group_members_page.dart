import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../core/presentation/load_failed_view.dart';
import '../../generated/locale_keys.g.dart';
import '../models/group.dart';
import '../state_management/group_bloc.dart';
import '../state_management/group_events.dart';
import '../state_management/group_state.dart';
import '../state_management/groups_bloc.dart';
import '../state_management/groups_events.dart';
import 'group_dialogs.dart';

/// The group's roster — who is in it and, for the owner, everything done *to*
/// people and to the group itself: hand the group over, remove a member, lift a
/// ban, rename, delete. Leaving lives here too.
///
/// Nothing here decides who may do what — the buttons only mirror what the
/// server allows, and every action goes back through it. Leaving is dispatched
/// to the app-wide `GroupsBloc` (it owns the user's list of groups and re-reads
/// the feature flags afterwards); everything else belongs to this screen.
///
/// The feed is the group's main screen; this page and the invite page hang off
/// its app-bar menu and deliberately show no events.
class GroupMembersPage extends StatelessWidget {
  const GroupMembersPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<GroupBloc>(param1: groupId)..add(const GroupOpened()),
      child: const _MembersView(),
    );
  }
}

class _MembersView extends StatelessWidget {
  const _MembersView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupBloc, GroupState>(
      listenWhen: (prev, curr) =>
          prev.closed != curr.closed ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          context.read<GroupBloc>().add(const GroupErrorShown());
        }
        // Deleted from this screen: the group's feed below is gone with it, so
        // the whole group stack is left, not just this page.
        if (state.closed) Routemaster.of(context).replace('/home');
      },
      builder: (context, state) {
        final group = state.group;
        return Scaffold(
          appBar: AppBar(
            title: Text(LocaleKeys.groups_members.tr()),
            actions: [
              if (group != null && state.isOwner)
                _OwnerMenu(group: group, busy: state.busy),
            ],
          ),
          body: switch ((state.loading, state.notFound, group)) {
            (true, _, null) => const Center(child: CircularProgressIndicator()),
            (_, true, _) => Center(
              child: Text(LocaleKeys.groups_notFound.tr()),
            ),
            // Прочитать группу не удалось: пустой экран не объяснял ничего, а
            // объяснение уезжало вместе со снек-баром. Теперь оно здесь — с
            // кнопкой «повторить» (и блок перечитает сам, когда вернётся сеть).
            (_, _, null) when state.failed => LoadFailedView(
              offline: state.failedOffline,
              message: state.failedOffline
                  ? LocaleKeys.network_noConnection.tr()
                  : null,
              onRetry: () => context.read<GroupBloc>().add(const GroupOpened()),
            ),
            (_, _, null) => const SizedBox.shrink(),
            (_, _, final Group group) => _MembersBody(
              group: group,
              state: state,
            ),
          },
        );
      },
    );
  }
}

class _MembersBody extends StatelessWidget {
  const _MembersBody({required this.group, required this.state});

  final Group group;
  final GroupState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (state.busy) const LinearProgressIndicator(),
        for (final member in group.members)
          _MemberTile(member: member, state: state),
        if (state.isOwner && group.bannedMembers.isNotEmpty) ...[
          _SectionTitle(LocaleKeys.groups_banned.tr()),
          for (final ban in group.bannedMembers)
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(ban.displayName),
              trailing: TextButton(
                onPressed: state.busy
                    ? null
                    : () => context.read<GroupBloc>().add(
                        GroupMemberUnbanned(ban.userId),
                      ),
                child: Text(LocaleKeys.groups_unban.tr()),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: group.viewerCanLeave
              ? OutlinedButton.icon(
                  onPressed: state.busy ? null : () => _leave(context, group),
                  icon: const Icon(Icons.logout),
                  label: Text(LocaleKeys.groups_leave.tr()),
                )
              : Text(
                  LocaleKeys.groups_leaveOwnerHint.tr(),
                  style: theme.textTheme.bodySmall,
                ),
        ),
      ],
    );
  }

  Future<void> _leave(BuildContext context, Group group) async {
    final bloc = context.read<GroupsBloc>();
    final confirmed = await confirmAction(
      context,
      title: LocaleKeys.groups_leaveConfirmTitle.tr(),
      body: LocaleKeys.groups_leaveConfirmBody.tr(args: [group.name]),
      action: LocaleKeys.groups_leave.tr(),
    );
    if (!confirmed || !context.mounted) return;
    bloc.add(GroupLeaveRequested(group.id));
    // The feed below this page belongs to a group the user just left.
    Routemaster.of(context).replace('/home');
  }
}

/// Rename / delete, behind the app-bar overflow. Deleting is only offered once
/// the owner is the last one left — the same condition the server checks.
class _OwnerMenu extends StatelessWidget {
  const _OwnerMenu({required this.group, required this.busy});

  final Group group;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      enabled: !busy,
      itemBuilder: (menuContext) => [
        PopupMenuItem<void>(
          onTap: () => _rename(context),
          child: Text(LocaleKeys.groups_rename.tr()),
        ),
        PopupMenuItem<void>(
          enabled: group.canBeDeleted,
          onTap: group.canBeDeleted ? () => _delete(context) : null,
          child: Text(
            group.canBeDeleted
                ? LocaleKeys.groups_delete.tr()
                : LocaleKeys.groups_deleteHint.tr(),
          ),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context) async {
    final bloc = context.read<GroupBloc>();
    final name = await showGroupNameDialog(context, initialName: group.name);
    if (name == null) return;
    bloc.add(GroupRenamed(name));
  }

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<GroupBloc>();
    final confirmed = await confirmAction(
      context,
      title: LocaleKeys.groups_deleteConfirmTitle.tr(),
      body: LocaleKeys.groups_deleteConfirmBody.tr(args: [group.name]),
      action: LocaleKeys.groups_delete.tr(),
    );
    if (!confirmed) return;
    bloc.add(const GroupDeleted());
  }
}

/// One member: their name, whether they own the group, and — for the owner —
/// "hand the group over" and "remove".
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.state});

  final GroupMember member;
  final GroupState state;

  @override
  Widget build(BuildContext context) {
    final owner = state.isOwner && !member.isOwner;
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          member.displayName.isEmpty
              ? '?'
              : member.displayName.characters.first,
        ),
      ),
      title: Text(member.displayName),
      subtitle: member.isOwner ? Text(LocaleKeys.groups_owner.tr()) : null,
      trailing: owner
          ? PopupMenuButton<void>(
              enabled: !state.busy,
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => _transfer(context),
                  child: Text(LocaleKeys.groups_transfer.tr()),
                ),
                PopupMenuItem<void>(
                  onTap: () => _remove(context),
                  child: Text(LocaleKeys.groups_remove.tr()),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _transfer(BuildContext context) async {
    final bloc = context.read<GroupBloc>();
    final confirmed = await confirmAction(
      context,
      title: LocaleKeys.groups_transferConfirmTitle.tr(),
      body: LocaleKeys.groups_transferConfirmBody.tr(
        args: [member.displayName],
      ),
      action: LocaleKeys.groups_confirm.tr(),
    );
    if (!confirmed) return;
    bloc.add(GroupOwnershipTransferred(member.userId));
  }

  Future<void> _remove(BuildContext context) async {
    final bloc = context.read<GroupBloc>();
    final confirmed = await confirmAction(
      context,
      title: LocaleKeys.groups_removeConfirmTitle.tr(),
      body: LocaleKeys.groups_removeConfirmBody.tr(args: [member.displayName]),
      action: LocaleKeys.groups_remove.tr(),
    );
    if (!confirmed) return;
    bloc.add(GroupMemberRemoved(member.userId));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
