import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/group_bloc.dart';
import '../state_management/group_events.dart';
import '../state_management/group_state.dart';
import 'group_invite_card.dart';

/// The invite the owner hands out: the code, the link and the QR, plus issuing
/// and revoking. Owner-only — the feed's menu doesn't offer it to anyone else,
/// and the server refuses the calls anyway.
class GroupInvitePage extends StatelessWidget {
  const GroupInvitePage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<GroupBloc>(param1: groupId)..add(const GroupOpened()),
      child: const _InviteView(),
    );
  }
}

class _InviteView extends StatelessWidget {
  const _InviteView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupBloc, GroupState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        context.read<GroupBloc>().add(const GroupErrorShown());
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(LocaleKeys.groups_invite_title.tr())),
          body: switch ((state.loading, state.notFound, state.group)) {
            (true, _, null) => const Center(child: CircularProgressIndicator()),
            (_, true, _) => Center(
              child: Text(LocaleKeys.groups_notFound.tr()),
            ),
            (_, _, null) => const SizedBox.shrink(),
            _ => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (state.busy) const LinearProgressIndicator(),
                GroupInviteCard(state: state),
              ],
            ),
          },
        );
      },
    );
  }
}
