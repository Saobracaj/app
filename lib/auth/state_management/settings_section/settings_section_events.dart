import 'settings_section_state.dart';

sealed class SettingsSectionEvent {}

/// Нажатие пункта левого меню на широком экране.
class SettingsSectionSelected extends SettingsSectionEvent {
  SettingsSectionSelected(this.section);
  final SettingsSection section;
}
