import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../auth/state_management/auth_cubit.dart';
import '../db/dependencies.dart';
import '../generated/locale_keys.g.dart';

/// Wraps the app and, once the user is authenticated, checks the back-end for an
/// active session opened on another device. If there is one — and it points
/// somewhere other than the current screen — it offers a "continue where you
/// left off" action that navigates there.
///
/// This is the pull side of cross-device continuity and also the "state after
/// login" corner case: the check runs whenever auth transitions to
/// authenticated (login) and once on startup if already signed in.
class SessionResumeGate extends StatefulWidget {
  const SessionResumeGate({
    super.key,
    required this.delegate,
    required this.child,
  });

  final RoutemasterDelegate delegate;
  final Widget child;

  @override
  State<SessionResumeGate> createState() => _SessionResumeGateState();
}

class _SessionResumeGateState extends State<SessionResumeGate> {
  // Guards against re-prompting within a single signed-in session; reset on sign-out.
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // Already signed in at startup: the BlocListener won't see a transition.
    if (context.read<AuthCubit>().state.isAuthenticated) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerResume());
    }
  }

  Future<void> _offerResume() async {
    final remote = await sessionSync.fetchResumable();
    if (remote == null || !mounted) return;

    // Don't offer to go where we already are.
    final current = widget.delegate.currentConfiguration?.fullPath;
    if (remote.location == current) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.session_resume_prompt.tr()),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: LocaleKeys.session_resume_action.tr(),
          onPressed: () => widget.delegate.push(remote.location),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) {
        if (state.isAuthenticated) {
          if (_checked) return;
          _checked = true;
          _offerResume();
        } else {
          // Signed out — allow a fresh check on the next sign-in.
          _checked = false;
        }
      },
      child: widget.child,
    );
  }
}
