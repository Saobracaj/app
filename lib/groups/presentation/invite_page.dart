import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../generated/locale_keys.g.dart';
import '../domain/invite_code.dart';
import '../state_management/groups_bloc.dart';
import '../state_management/groups_events.dart';

/// Where an invite link lands: `https://saobracaj.gleb.at/invite/ABC-DEF-GHI`.
///
/// The page itself is a doorway, not a screen. Resolving a code and asking
/// "join this group?" already exists on the home screen — the invite arrives
/// there, so a link and a typed-in code go through exactly one flow. All this
/// does is check the code is a code, hand it over and step aside.
///
/// A signed-out visitor is asked to sign in first: a group has members, and a
/// member is an account. The code stays in the address bar, so coming back to
/// the link after signing in works.
class InvitePage extends StatelessWidget {
  const InvitePage({super.key, required this.token});

  /// The code as it came out of the URL, in whatever case and shape.
  final String token;

  @override
  Widget build(BuildContext context) {
    final code = normalizeInviteCode(token) ?? inviteCodeFromLink(token);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        if (code == null) {
          return _InviteMessage(
            message: LocaleKeys.groups_codeInvalid.tr(),
            action: LocaleKeys.groups_invite_openApp.tr(),
            onPressed: () => Routemaster.of(context).replace('/home'),
          );
        }
        return switch (auth.status) {
          AuthStatus.unknown => const _InviteMessage(),
          AuthStatus.unauthenticated => _InviteMessage(
            message: LocaleKeys.groups_invite_signInToJoin.tr(args: [code]),
            action: LocaleKeys.groups_invite_signIn.tr(),
            onPressed: () => Routemaster.of(context).push('/login'),
          ),
          AuthStatus.authenticated => _AcceptInvite(code: code),
        };
      },
    );
  }
}

/// Hand the code to the app-wide [GroupsBloc] and go home, where the invite is
/// confirmed by the same dialog a typed-in code gets.
class _AcceptInvite extends StatefulWidget {
  const _AcceptInvite({required this.code});

  final String code;

  @override
  State<_AcceptInvite> createState() => _AcceptInviteState();
}

class _AcceptInviteState extends State<_AcceptInvite> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the home route has to exist before the dialog that
    // opens on it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GroupsBloc>().add(GroupInvitePreviewRequested(widget.code));
      Routemaster.of(context).replace('/home');
    });
  }

  @override
  Widget build(BuildContext context) => const _InviteMessage();
}

/// The whole page: a line of text and at most one button. Also the spinner
/// state, when there is nothing to say yet.
class _InviteMessage extends StatelessWidget {
  const _InviteMessage({this.message, this.action, this.onPressed});

  final String? message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.groups_joinTitle.tr())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message == null) const CircularProgressIndicator(),
              if (message != null)
                Text(message!, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onPressed, child: Text(action!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
