import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_section_state.freezed.dart';

/// Разделы экрана настроек — пункты левого меню широкой раскладки. На телефоне
/// каждый раздел остаётся отдельным экраном со своим маршрутом.
enum SettingsSection {
  profile,
  appearance,
  notifications,
  supportChat,
  supportThreads,
  moderation,
  testPush,
  features,
  about,
}

/// Состояние широкой раскладки настроек: какой раздел показан в правой панели.
///
/// `null` — раздел ещё не выбирали; страница показывает профиль (карточку
/// аккаунта), как и раньше. Выбор намеренно не попадает в URL: по задаче
/// переключение разделов не должно открывать отдельный экран, а прямые ссылки
/// на полноэкранные версии разделов продолжают работать.
@freezed
abstract class SettingsSectionState with _$SettingsSectionState {
  const factory SettingsSectionState({SettingsSection? selected}) =
      _SettingsSectionState;
}
