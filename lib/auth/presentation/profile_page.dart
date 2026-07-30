import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../generated/locale_keys.g.dart';
import '../../theme/theme_cubit.dart';
import '../state_management/auth_cubit.dart';

/// Settings screen reachable from the profile icon: account (login / logout),
/// appearance (accent color + light/dark mode) and notification preferences.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.settings_title.tr())),
      body: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, auth) {
            return ListView(
              children: [
                _SectionHeader(LocaleKeys.settings_account.tr()),
                if (auth.isAuthenticated)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      LocaleKeys.settings_signedInAs.tr(
                        args: [auth.viewer?.email ?? ''],
                      ),
                    ),
                    trailing: TextButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout),
                      label: Text(LocaleKeys.settings_logout.tr()),
                    ),
                  )
                else
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(LocaleKeys.settings_notAuthorized.tr()),
                    subtitle: Text(LocaleKeys.settings_loginPrompt.tr()),
                    trailing: FilledButton(
                      onPressed: () => Routemaster.of(context).push('/login'),
                      child: Text(LocaleKeys.settings_loginButton.tr()),
                    ),
                  ),
                const Divider(),
                _SectionHeader(LocaleKeys.settings_appearance.tr()),
                const _AccentPicker(),
                const _ThemeModePicker(),
                const Divider(),
                _SectionHeader(LocaleKeys.settings_notifications.tr()),
                SwitchListTile(
                  title: Text(LocaleKeys.settings_emailNotifications.tr()),
                  value: auth.emailNotifications,
                  onChanged: (v) =>
                      context.read<AuthCubit>().setEmailNotifications(v),
                ),
                SwitchListTile(
                  title: Text(LocaleKeys.settings_pushNotifications.tr()),
                  value: auth.pushNotifications,
                  onChanged: (v) =>
                      context.read<AuthCubit>().setPushNotifications(v),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final cubit = context.read<AuthCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.settings_logoutConfirmTitle.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocaleKeys.settings_logoutConfirmCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocaleKeys.settings_logoutConfirmOk.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.logout();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, theme) {
        return ListTile(
          title: Text(LocaleKeys.settings_accentColor.tr()),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 12,
              children: [
                for (var i = 0; i < kAppAccents.length; i++)
                  GestureDetector(
                    onTap: () => context.read<ThemeCubit>().setAccent(i),
                    child: CircleAvatar(
                      backgroundColor: kAppAccents[i].color,
                      radius: 18,
                      child: theme.accentIndex == i
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, theme) {
        return ListTile(
          title: Text(LocaleKeys.settings_themeMode.tr()),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(LocaleKeys.settings_themeSystem.tr()),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(LocaleKeys.settings_themeLight.tr()),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(LocaleKeys.settings_themeDark.tr()),
                ),
              ],
              selected: {theme.mode},
              onSelectionChanged: (s) =>
                  context.read<ThemeCubit>().setMode(s.first),
            ),
          ),
        );
      },
    );
  }
}
