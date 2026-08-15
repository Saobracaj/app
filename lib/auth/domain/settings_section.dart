/// Разделы экрана настроек.
///
/// Каждый раздел — свой адрес (`/settings/profile`, `/settings/appearance`, …),
/// а не внутреннее состояние экрана: на широком экране адрес выбирает раздел в
/// правой панели, на телефоне открывает его отдельным экраном. Благодаря этому
/// на раздел можно дать ссылку, а кнопки браузера «назад/вперёд» ходят по
/// разделам так же, как по остальным экранам.
enum SettingsSection {
  profile('profile'),
  appearance('appearance'),
  notifications('notifications'),
  supportChat('support'),
  supportThreads('support-threads'),
  moderation('moderation'),
  testPush('test-push'),
  features('features'),
  about('about');

  const SettingsSection(this.slug);

  /// Сегмент адреса раздела.
  final String slug;

  /// Полный путь раздела.
  String get path => '/settings/$slug';

  /// Раздел по сегменту адреса, либо `null` для незнакомого сегмента.
  static SettingsSection? bySlug(String? slug) {
    for (final section in values) {
      if (section.slug == slug) return section;
    }
    return null;
  }
}
