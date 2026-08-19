import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../billing_admin/presentation/billing_admin_page.dart';
import '../../core/di.dart';
import '../../core/presentation/wide_layout.dart';
import '../../core/responsive.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/presentation/feature_flags_page.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../profile/presentation/display_name_page.dart';
import '../../profile/state_management/display_name_bloc.dart';
import '../../profile/state_management/display_name_events.dart';
import '../../push_test/presentation/test_push_page.dart';
import '../../subscription/presentation/subscription_page.dart';
import '../../chat/presentation/chat_page.dart';
import '../../chat/presentation/support_chats_page.dart';
import '../../test/about/about_page.dart';
import '../../theme/presentation/appearance_page.dart';
import '../domain/settings_section.dart';
import '../state_management/auth/auth_bloc.dart';
import '../state_management/auth/auth_events.dart';
import '../state_management/auth/auth_state.dart';

/// Один пункт меню настроек: раздел и его строка в списке.
class _SettingsEntry {
  const _SettingsEntry({
    required this.section,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final SettingsSection section;
  final IconData icon;
  final String title;
  final String subtitle;
}

/// Settings menu (the "Settings" bottom-navigation tab, also reachable from the
/// profile icon): account (login / logout) plus the settings sections.
///
/// Раздел выбирается адресом ([SettingsSection.path]), а не внутренним
/// состоянием экрана: на телефоне `/settings/appearance` — отдельный экран
/// раздела, на широком экране — то же меню слева и раздел в правой панели.
/// Поэтому нажатие на профиль в боковой колонке (`/settings/profile`) выглядит
/// ровно так же, как выбор пункта «Профиль» в самом меню.
///
/// На широком экране у самого `/settings` нет собственного вида: справа и так
/// стоит раздел профиля (карточка аккаунта). Поэтому там адрес сразу
/// подменяется на `/settings/profile` — иначе первое нажатие на «Профиль»
/// открывало бы поверх точно такой же экран с анимацией перехода, а «назад»
/// вело бы на его копию (задача 1217517553850759).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.section});

  /// Открытый раздел; `null` — сам экран настроек (список пунктов на телефоне,
  /// меню с карточкой аккаунта справа на широком экране).
  final SettingsSection? section;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final entries = _entries(context, auth);
        // Адрес может называть раздел, которого у этого пользователя нет
        // (ссылка на модерацию без прав, `/settings/notifications` после
        // выхода) — тогда экран ведёт себя как обычные настройки.
        final available = entries.map((e) => e.section).toSet();
        final section = available.contains(this.section) ? this.section : null;

        // Широкий экран: слева — колонка разделов настроек, справа — панель
        // выбранного раздела (макет веб-версии).
        if (context.isExpandedScreen) {
          if (this.section == null) _openProfileSection(context);
          return _WideSettings(auth: auth, entries: entries, section: section);
        }

        // Телефон: раздел — отдельный экран, как и раньше.
        if (section != null) return _sectionScreen(section);

        return Scaffold(
          appBar: AppBar(title: Text(LocaleKeys.settings_title.tr())),
          body: SafeArea(
            child: ReadableWidth(
              child: ListView(
                children: [
                  _SectionHeader(LocaleKeys.settings_account.tr()),
                  _accountTile(context, auth),
                  const Divider(height: 0),
                  for (final entry in entries) ...[
                    ListTile(
                      leading: Icon(entry.icon),
                      title: Text(entry.title),
                      subtitle: Text(entry.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Routemaster.of(context).push(entry.section.path),
                    ),
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

  /// Широкий экран по адресу `/settings`: после кадра подменяет адрес на
  /// `/settings/profile` — раздел, который правая панель показывает и так.
  ///
  /// Только пока этот экран сверху: страница `/settings` остаётся в стеке под
  /// разделами и перестраивается вместе с ними (смена состояния входа), а
  /// уводить пользователя с открытого раздела она не должна. Маршрутная
  /// таблица сделать этот редирект не может — она не знает ширины экрана, а
  /// на телефоне `/settings` — полноценный список.
  void _openProfileSection(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final router = Routemaster.of(context);
      if (router.currentRoute.path != RouteData.maybeOf(context)?.path) return;
      router.replace(SettingsSection.profile.path);
    });
  }

  /// Полноэкранная версия раздела — те же экраны, что открываются по своим
  /// собственным (историческим) адресам вроде `/appearance`.
  Widget _sectionScreen(SettingsSection section) => switch (section) {
    SettingsSection.profile => const DisplayNamePage(),
    SettingsSection.subscription => const SubscriptionPage(),
    SettingsSection.appearance => const AppearancePage(),
    SettingsSection.notifications => const NotificationsPage(),
    SettingsSection.supportChat => const ChatPage(),
    SettingsSection.supportThreads => const SupportChatsPage(),
    SettingsSection.billing => const BillingAdminPage(),
    SettingsSection.testPush => const TestPushPage(),
    SettingsSection.features => const FeatureFlagsPage(),
    SettingsSection.about => const AboutPage(),
  };

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
  static List<_SettingsEntry> _entries(BuildContext context, AuthState auth) {
    final permissions = auth.viewer?.permissions ?? const <String>[];
    return [
      // Профиль — отдельный пункт меню: отображаемое имя и аккаунт. Без входа
      // профиля нет, поэтому пункт виден только авторизованным.
      if (auth.isAuthenticated)
        _SettingsEntry(
          section: SettingsSection.profile,
          icon: Icons.person_outline,
          title: 'settings.profile'.tr(),
          subtitle: 'settings.profileSubtitle'.tr(),
        ),
      // Подписка — только веб и только для вошедшего: заказ привязан к
      // аккаунту, а в мобильных сборках о подписке не говорим вовсе.
      if (kIsWeb && auth.isAuthenticated)
        _SettingsEntry(
          section: SettingsSection.subscription,
          icon: Icons.card_membership_outlined,
          title: LocaleKeys.subscription_title.tr(),
          subtitle: LocaleKeys.subscription_settingsSubtitle.tr(),
        ),
      _SettingsEntry(
        section: SettingsSection.appearance,
        icon: Icons.palette_outlined,
        title: LocaleKeys.settings_appearance.tr(),
        subtitle: LocaleKeys.settings_appearanceSubtitle.tr(),
      ),
      // Notifications only make sense for a signed-in account, so the
      // entry is hidden while signed out.
      if (auth.isAuthenticated)
        _SettingsEntry(
          section: SettingsSection.notifications,
          icon: Icons.notifications_outlined,
          title: LocaleKeys.settings_notifications.tr(),
          subtitle: LocaleKeys.settings_notificationsSubtitle.tr(),
        ),
      // The chat with the developers: signed-in only (the thread is
      // keyed by the account) and behind the `support_chat` flag,
      // which is what the catalog already reserved it for.
      if (auth.isAuthenticated &&
          context.watch<FeatureFlagsBloc>().state.isEnabled(
            AppFeature.supportChat,
          ))
        _SettingsEntry(
          section: SettingsSection.supportChat,
          icon: Icons.support_agent_outlined,
          title: 'support.title'.tr(),
          subtitle: 'support.settingsSubtitle'.tr(),
        ),
      // The list of обращения, gated on the backend
      // `moderate_support` permission, so only support staff see it.
      if (permissions.contains('moderate_support'))
        _SettingsEntry(
          section: SettingsSection.supportThreads,
          icon: Icons.inbox_outlined,
          title: 'support.threadsTitle'.tr(),
          subtitle: 'support.threadsSubtitle'.tr(),
        ),
      // Денежный стол: заказы, подтверждение оплаты, подписки вручную,
      // тарифы и реквизиты. Гейт — бэкендовое право `manage_billing`; оно
      // же стоит на каждом запросе. Показывается и в мобильных сборках: это
      // инструмент оператора, а не разговор с покупателем о подписке.
      if (permissions.contains('manage_billing'))
        _SettingsEntry(
          section: SettingsSection.billing,
          icon: Icons.payments_outlined,
          title: LocaleKeys.billingAdmin_title.tr(),
          subtitle: LocaleKeys.billingAdmin_settingsSubtitle.tr(),
        ),
      // Инструмент администратора: тестовая отправка пуша по почте.
      // Гейт — бэкендовое право `send_test_push`, оно же проверяется
      // и на самой мутации.
      if (permissions.contains('send_test_push'))
        _SettingsEntry(
          section: SettingsSection.testPush,
          icon: Icons.notifications_active_outlined,
          title: 'settings.testPush'.tr(),
          subtitle: 'settings.testPushSubtitle'.tr(),
        ),
      _SettingsEntry(
        section: SettingsSection.features,
        icon: Icons.tune,
        title: 'settings.features'.tr(),
        subtitle: 'settings.featuresSubtitle'.tr(),
      ),
      _SettingsEntry(
        section: SettingsSection.about,
        icon: Icons.info_outline_rounded,
        title: LocaleKeys.settings_about.tr(),
        subtitle: LocaleKeys.settings_aboutSubtitle.tr(),
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

/// Широкая раскладка настроек: меню слева, контент выбранного раздела справа.
/// По задаче пункт меню не открывает отдельный экран — контент раздела
/// подменяется прямо в правой панели.
class _WideSettings extends StatelessWidget {
  const _WideSettings({
    required this.auth,
    required this.entries,
    required this.section,
  });

  final AuthState auth;
  final List<_SettingsEntry> entries;

  /// Раздел из адреса; `null` — раздел не выбран, справа карточка аккаунта.
  final SettingsSection? section;

  @override
  Widget build(BuildContext context) {
    final withSidebar = context.isLargeScreen;
    return Scaffold(
      // Без стрелки «назад»: под разделом в стеке лежит `/settings`, но на
      // широком экране это тот же самый экран — возвращаться там некуда.
      appBar: withSidebar
          ? null
          : AppBar(
              title: Text(LocaleKeys.settings_title.tr()),
              automaticallyImplyLeading: false,
            ),
      backgroundColor: widePageBackground(context),
      body: WideContent(
        maxWidth: 1140,
        padding: const EdgeInsets.fromLTRB(40, 34, 40, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (withSidebar)
              PageHeading(
                title: LocaleKeys.settings_title.tr(),
                bottomSpacing: 24,
              ),
            Expanded(
              // Раздела в адресе может не быть (`/settings`) — справа тогда,
              // как и до первого выбора, карточка аккаунта/профиль.
              child: Builder(
                builder: (context) {
                  final selected = section ?? SettingsSection.profile;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 300,
                        child: SingleChildScrollView(
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final entry in entries)
                                  ListTile(
                                    leading: Icon(entry.icon),
                                    title: Text(entry.title),
                                    trailing: const Icon(Icons.chevron_right),
                                    selected: entry.section == selected,
                                    onTap: () => Routemaster.of(
                                      context,
                                    ).push(entry.section.path),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: _SectionPanel(section: selected, auth: auth),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Правая панель широкой раскладки: контент выбранного раздела.
///
/// Короткие разделы — карточка по содержимому со своей прокруткой страницы;
/// разделы с собственным внутренним скроллом (модерация, обращения, чат) —
/// карточка на всю высоту панели.
class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.section, required this.auth});

  final SettingsSection section;
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    // Карточка по содержимому: прокручивается панель, а не контент.
    Widget hug(Widget card) => SingleChildScrollView(child: card);

    return switch (section) {
      SettingsSection.profile => hug(_AccountPanel(auth: auth)),
      SettingsSection.subscription => const SubscriptionContent(),
      SettingsSection.appearance => hug(
        const SurfaceCard(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: AppearanceContent(),
        ),
      ),
      SettingsSection.notifications => hug(
        const SurfaceCard(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: NotificationsContent(),
        ),
      ),
      SettingsSection.supportChat => const SurfaceCard(
        padding: EdgeInsets.zero,
        child: ChatContent(),
      ),
      SettingsSection.supportThreads => const SurfaceCard(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SupportChatsContent(),
      ),
      SettingsSection.billing => const SurfaceCard(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: BillingAdminContent(),
      ),
      SettingsSection.testPush => hug(
        const SurfaceCard(
          padding: EdgeInsets.all(24),
          child: TestPushContent(),
        ),
      ),
      SettingsSection.features => hug(
        const SurfaceCard(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: FeatureFlagsContent(),
        ),
      ),
      SettingsSection.about => hug(
        const SurfaceCard(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: AboutContent(),
        ),
      ),
    };
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

/// Карточка аккаунта — раздел «Профиль» правой панели.
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
            // Содержимое профиля (отображаемое имя, удаление аккаунта) — прямо
            // на странице настроек, а не за отдельным переходом.
            BlocProvider(
              create: (_) =>
                  getIt<DisplayNameBloc>()..add(DisplayNameStarted()),
              child: const DisplayNameContent(),
            ),
          ],
        ],
      ),
    );
  }
}
