import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../generated/locale_keys.g.dart';
import '../../theme/state_management/theme_bloc.dart';
import '../../theme/state_management/theme_events.dart';

/// Боковая навигация веб-версии: логотип, разделы приложения и блок аккаунта
/// внизу с переключателем темы.
///
/// Заменяет [NavigationRail] на широких окнах (>=1200) — в макете это колонка
/// шириной 244 с фоном `--sclow`, разделительной линией справа и подписанными
/// пунктами; на планшетах (600–1200) остаётся обычный rail.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<SidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Ширина колонки из макета (`width:244px`).
  static const double width = 244;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Material, а не Container: ink-эффекты пунктов (подсветка выбранного,
    // hover) рисуются на ближайшем Material-предке, и непрозрачный Container
    // поверх него их полностью перекрывал.
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: width,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Brand(),
                const SizedBox(height: 12),
                for (var i = 0; i < destinations.length; i++)
                  _SidebarTile(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                const Spacer(),
                const _AccountBlock(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Один пункт боковой навигации.
class SidebarDestination {
  const SidebarDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Saobraćaj',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final SidebarDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      // Собственный Material пункта: и заливка выбранного состояния, и
      // hover-подсветка InkWell живут на одной поверхности и потому видимы.
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Нижний блок колонки: кто вошёл (или приглашение войти) и переключатель темы.
class _AccountBlock extends StatelessWidget {
  const _AccountBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final email = auth.viewer?.email ?? '';
        final letter = email.isNotEmpty ? email[0].toUpperCase() : '?';
        final name = email.isNotEmpty ? email.split('@').first : email;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(color: theme.colorScheme.outlineVariant, height: 17),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => Routemaster.of(
                context,
              ).push(auth.isAuthenticated ? '/profile' : '/login'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: auth.isAuthenticated
                          ? Text(
                              letter,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            )
                          : Icon(
                              Icons.person_outline,
                              size: 18,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            auth.isAuthenticated
                                ? name
                                : LocaleKeys.settings_loginButton.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            LocaleKeys.settings_account.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _ThemeToggle(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Кнопка «◐» из макета: перебирает системную → светлую → тёмную тему.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        const order = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
        final next = order[(order.indexOf(state.mode) + 1) % order.length];
        return IconButton(
          tooltip: LocaleKeys.settings_themeMode.tr(),
          visualDensity: VisualDensity.compact,
          icon: Icon(switch (state.mode) {
            ThemeMode.system => Icons.brightness_auto_outlined,
            ThemeMode.light => Icons.light_mode_outlined,
            ThemeMode.dark => Icons.dark_mode_outlined,
          }, size: 18),
          onPressed: () => context.read<ThemeBloc>().add(ModeChanged(next)),
        );
      },
    );
  }
}
