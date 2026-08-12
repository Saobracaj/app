import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/presentation/wide_layout.dart';
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
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        // Широкий экран: слева — колонка разделов настроек, справа — панель
        // аккаунта (макет веб-версии).
        if (context.isExpandedScreen) {
          final withSidebar = context.isLargeScreen;
          return Scaffold(
            appBar: withSidebar
                ? null
                : AppBar(title: Text(LocaleKeys.settings_title.tr())),
            backgroundColor: widePageBackground(context),
            body: ListView(
              children: [
                WideContent(
                  maxWidth: 1140,
                  padding: const EdgeInsets.fromLTRB(40, 34, 40, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (withSidebar)
                        PageHeading(
                          title: LocaleKeys.settings_title.tr(),
                          bottomSpacing: 24,
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 300,
                            child: SurfaceCard(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _menuTiles(
                                  context,
                                  auth,
                                  compact: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(child: _AccountPanel(auth: auth)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(LocaleKeys.settings_title.tr())),
          body: SafeArea(
            child: ReadableWidth(
              child: ListView(
                children: [
                  _SectionHeader(LocaleKeys.settings_account.tr()),
                  _accountTile(context, auth),
                  const Divider(height: 0),
                  for (final tile in _menuTiles(context, auth)) ...[
                    tile,
                    const Divider(height: 0),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Строка аккаунта мобильного списка: кто вошёл (и выход) либо приглашение
  /// войти.
  Widget _accountTile(BuildContext context, AuthState auth) {
    if (auth.isAuthenticated) {
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(
          LocaleKeys.settings_signedInAs.tr(args: [auth.viewer?.email ?? '']),
        ),
        // Tapping the account row opens the profile screen (display
        // name + delete account).
        onTap: () => Routemaster.of(context).push('/displayName'),
        trailing: TextButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout),
          label: Text(LocaleKeys.settings_logout.tr()),
        ),
      );
    }
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(LocaleKeys.settings_notAuthorized.tr()),
      subtitle: Text(LocaleKeys.settings_loginPrompt.tr()),
      trailing: FilledButton(
        onPressed: () => Routemaster.of(context).push('/login'),
        child: Text(LocaleKeys.settings_loginButton.tr()),
      ),
    );
  }

  /// Разделы настроек — один и тот же набор в обеих раскладках. Часть из них
  /// закрыта фича-флагами и правами (их проверяет ещё и бэкенд).
  /// В колонке широкого экрана пояснения под названиями раздувают строки на
  /// три полосы — там раздел показывается одним названием ([compact]).
  List<Widget> _menuTiles(
    BuildContext context,
    AuthState auth, {
    bool compact = false,
  }) {
    final permissions = auth.viewer?.permissions ?? const <String>[];
    Widget? subtitle(String text) => compact ? null : Text(text);
    return [
      ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(LocaleKeys.settings_appearance.tr()),
        subtitle: subtitle(LocaleKeys.settings_appearanceSubtitle.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Routemaster.of(context).push('/appearance'),
      ),
      // Notifications only make sense for a signed-in account, so the
      // entry is hidden while signed out.
      if (auth.isAuthenticated)
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(LocaleKeys.settings_notifications.tr()),
          subtitle: subtitle(LocaleKeys.settings_notificationsSubtitle.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Routemaster.of(context).push('/notifications'),
        ),
      // The chat with the developers: signed-in only (the thread is
      // keyed by the account) and behind the `support_chat` flag,
      // which is what the catalog already reserved it for.
      if (auth.isAuthenticated &&
          context.watch<FeatureFlagsBloc>().state.isEnabled(
            AppFeature.supportChat,
          ))
        ListTile(
          leading: const Icon(Icons.support_agent_outlined),
          title: Text('support.title'.tr()),
          subtitle: subtitle('support.settingsSubtitle'.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Routemaster.of(context).push('/support'),
        ),
      // The list of обращения, gated on the backend
      // `moderate_support` permission, so only support staff see it.
      if (permissions.contains('moderate_support'))
        ListTile(
          leading: const Icon(Icons.inbox_outlined),
          title: Text('support.threadsTitle'.tr()),
          subtitle: subtitle('support.threadsSubtitle'.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Routemaster.of(context).push('/support/threads'),
        ),
      // Moderation is gated on the backend `moderate_comments`
      // permission, so the entry only appears for moderators.
      if (permissions.contains('moderate_comments'))
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(LocaleKeys.comments_moderation_title.tr()),
          subtitle: subtitle(LocaleKeys.comments_moderation_subtitle.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Routemaster.of(context).push('/moderation'),
        ),
      // Инструмент администратора: тестовая отправка пуша по почте.
      // Гейт — бэкендовое право `send_test_push`, оно же проверяется
      // и на самой мутации.
      if (permissions.contains('send_test_push'))
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text('settings.testPush'.tr()),
          subtitle: subtitle('settings.testPushSubtitle'.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Routemaster.of(context).push('/testPush'),
        ),
      ListTile(
        leading: const Icon(Icons.tune),
        title: Text('settings.features'.tr()),
        subtitle: subtitle('settings.featuresSubtitle'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Routemaster.of(context).push('/features'),
      ),
      ListTile(
        leading: const Icon(Icons.info_outline_rounded),
        title: Text(LocaleKeys.settings_about.tr()),
        subtitle: subtitle(LocaleKeys.settings_aboutSubtitle.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Routemaster.of(context).push('/about'),
      ),
    ];
  }

  static Future<void> _confirmLogout(BuildContext context) async {
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

/// Правая панель настроек на широком экране: карточка аккаунта.
class _AccountPanel extends StatelessWidget {
  const _AccountPanel({required this.auth});

  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = auth.viewer?.email ?? '';
    final letter = email.isNotEmpty ? email[0].toUpperCase() : '?';
    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: auth.isAuthenticated
                    ? Text(
                        letter,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auth.isAuthenticated
                          ? email
                          : LocaleKeys.settings_notAuthorized.tr(),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      auth.isAuthenticated
                          ? LocaleKeys.settings_signedIn.tr()
                          : LocaleKeys.settings_loginPrompt.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (auth.isAuthenticated)
                OutlinedButton(
                  onPressed: () => ProfilePage._confirmLogout(context),
                  child: Text(LocaleKeys.settings_logout.tr()),
                )
              else
                FilledButton(
                  onPressed: () => Routemaster.of(context).push('/login'),
                  child: Text(LocaleKeys.settings_loginButton.tr()),
                ),
            ],
          ),
          if (auth.isAuthenticated) ...[
            const SizedBox(height: 20),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text(LocaleKeys.comments_displayName_title.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Routemaster.of(context).push('/displayName'),
            ),
          ],
        ],
      ),
    );
  }
}
