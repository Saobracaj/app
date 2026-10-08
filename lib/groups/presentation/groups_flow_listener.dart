import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../state_management/groups_bloc.dart';
import '../state_management/groups_events.dart';
import '../state_management/groups_state.dart';
import 'group_dialogs.dart';

/// Доводит до конца то, что начал [GroupsBloc]: показывает подтверждение
/// приглашения и открывает только что созданную (или принятую) группу.
///
/// Слушатель стоит один раз в оболочке с вкладками (`HomePage`), а не на
/// экране, откуда нажали кнопку: код приглашения приходит и по ссылке
/// (`/invite/ABC-DEF-GHI` отдаёт его блоку и уходит на главную), и из раздела
/// «Группы» в настройках — а вкладки живут одновременно, так что два
/// слушателя показали бы диалог дважды.
class GroupsFlowListener extends StatelessWidget {
  const GroupsFlowListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupsBloc, GroupsState>(
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
      child: child,
    );
  }
}
