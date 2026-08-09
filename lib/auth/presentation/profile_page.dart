import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/responsive.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/auth/auth_bloc.dart';
import '../state_management/auth/auth_events.dart';
import '../state_management/auth/auth_state.dart';

/// Settings menu (the "Settings" bottom-navigation tab, also reachable from the
/// profile icon): account (login / logout) plus rows opening the Appearance,
/// Notifications (signed-in only) and About screens.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.settings_title.tr())),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) {
            return ReadableWidth(
              child: ListView(
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
                      // Tapping the account row opens the profile screen (display
                      // name + delete account).
                      onTap: () => Routemaster.of(context).push('/displayName'),
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
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(LocaleKeys.settings_appearance.tr()),
                    subtitle: Text(LocaleKeys.settings_appearanceSubtitle.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Routemaster.of(context).push('/appearance'),
                  ),
                  // Notifications only make sense for a signed-in account, so the
                  // entry is hidden while signed out.
                  if (auth.isAuthenticated) ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(LocaleKeys.settings_notifications.tr()),
                      subtitle: Text(
                        LocaleKeys.settings_notificationsSubtitle.tr(),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Routemaster.of(context).push('/notifications'),
                    ),
                  ],
                  // The chat with the developers: signed-in only (the thread is
                  // keyed by the account) and behind the `support_chat` flag,
                  // which is what the catalog already reserved it for.
                  if (auth.isAuthenticated &&
                      context.watch<FeatureFlagsBloc>().state.isEnabled(
                        AppFeature.supportChat,
                      )) ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.support_agent_outlined),
                      title: Text('support.title'.tr()),
                      subtitle: Text('support.settingsSubtitle'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Routemaster.of(context).push('/support'),
                    ),
                  ],
                  // The list of обращения, gated on the backend
                  // `moderate_support` permission, so only support staff see it.
                  if (auth.viewer?.permissions.contains('moderate_support') ==
                      true) ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: Text('support.threadsTitle'.tr()),
                      subtitle: Text('support.threadsSubtitle'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Routemaster.of(context).push('/support/threads'),
                    ),
                  ],
                  // Moderation is gated on the backend `moderate_comments`
                  // permission, so the entry only appears for moderators.
                  if (auth.viewer?.permissions.contains('moderate_comments') ==
                      true) ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: Text(LocaleKeys.comments_moderation_title.tr()),
                      subtitle: Text(
                        LocaleKeys.comments_moderation_subtitle.tr(),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Routemaster.of(context).push('/moderation'),
                    ),
                  ],
                  // Инструмент администратора: тестовая отправка пуша по почте.
                  // Гейт — бэкендовое право `send_test_push`, оно же проверяется
                  // и на самой мутации.
                  if (auth.viewer?.permissions.contains('send_test_push') ==
                      true) ...[
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text('settings.testPush'.tr()),
                      subtitle: Text('settings.testPushSubtitle'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Routemaster.of(context).push('/testPush'),
                    ),
                  ],
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text('settings.features'.tr()),
                    subtitle: Text('settings.featuresSubtitle'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Routemaster.of(context).push('/features'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(LocaleKeys.settings_about.tr()),
                    subtitle: Text(LocaleKeys.settings_aboutSubtitle.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Routemaster.of(context).push('/about'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
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
    if (confirmed == true) authBloc.add(LogoutRequested());
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
