import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state_management/groups_bloc.dart';
import '../state_management/groups_events.dart';
import '../state_management/groups_state.dart';

/// Surfaces a failed group call as a snackbar, wherever in the app it happened
/// (the home-screen cards, the group screen, a join dialog).
///
/// The server's own message is shown: it is the only place that knows *which*
/// rule refused the call — a full group, the fifth membership, an expired
/// invite, a ban — and it already answers in the caller's language.
class GroupsErrorListener extends StatelessWidget {
  const GroupsErrorListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupsBloc, GroupsState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        context.read<GroupsBloc>().add(const GroupsErrorShown());
      },
      child: child,
    );
  }
}
