import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../generated/locale_keys.g.dart';
import '../state_management/auth/auth_bloc.dart';
import '../state_management/auth/auth_state.dart';

/// App-bar action that shows a "Log in" button while signed out and a round
/// profile avatar once authenticated. Both route to the settings/profile screen
/// (the button routes to login directly for a faster path in).
class AuthButton extends StatelessWidget {
  const AuthButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.unknown) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (state.isAuthenticated) {
          final email = state.viewer?.email ?? '';
          final letter = email.isNotEmpty ? email[0].toUpperCase() : '?';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: IconButton(
              tooltip: LocaleKeys.auth_profileTooltip.tr(),
              onPressed: () => Routemaster.of(context).push('/settings/profile'),
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  letter,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            onPressed: () => Routemaster.of(context).push('/login'),
            icon: const Icon(Icons.login),
            label: Text(LocaleKeys.auth_loginNav.tr()),
          ),
        );
      },
    );
  }
}
