import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../state_management/theme_bloc.dart';
import '../state_management/theme_events.dart';

/// Standalone "Appearance" screen opened from the settings list: accent color
/// (including the platform "default" / dynamic option) and light/dark mode.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.settings_appearance.tr())),
      body: SafeArea(
        child: ListView(
          children: const [AppearanceContent(), SizedBox(height: 24)],
        ),
      ),
    );
  }
}

/// Содержимое раздела «Оформление» без собственного скролла — встраивается и в
/// отдельный экран, и в правую панель настроек на широком экране.
class AppearanceContent extends StatelessWidget {
  const AppearanceContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_AccentPicker(), _ThemeModePicker()],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, theme) {
        return ListTile(
          title: Text(LocaleKeys.settings_accentColor.tr()),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DefaultAccentSwatch(selected: theme.isDefaultAccent),
                for (var i = 0; i < kAppAccents.length; i++)
                  GestureDetector(
                    onTap: () =>
                        context.read<ThemeBloc>().add(AccentChanged(i)),
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

/// The "default" accent: dynamic (Material You) colors on Android, a seeded
/// fallback elsewhere. Rendered as an auto/palette swatch.
class _DefaultAccentSwatch extends StatelessWidget {
  const _DefaultAccentSwatch({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: LocaleKeys.settings_accentDefault.tr(),
      child: GestureDetector(
        onTap: () => context.read<ThemeBloc>().add(DefaultAccentSelected()),
        child: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          radius: 18,
          child: Icon(
            selected ? Icons.check : Icons.auto_awesome,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
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
                  context.read<ThemeBloc>().add(ModeChanged(s.first)),
            ),
          ),
        );
      },
    );
  }
}
