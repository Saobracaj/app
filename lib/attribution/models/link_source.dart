/// Источники ссылок и их воронка — зеркало
/// `saobracaj_backend/src/attribution/model.rs`.
library;

/// Место, где раздаётся ссылка: шапка Instagram, автошкола, листовка.
class LinkSource {
  const LinkSource({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.targetPath,
    required this.url,
    required this.createdAt,
    this.archivedAt,
  });

  factory LinkSource.fromJson(Map<String, dynamic> json) => LinkSource(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    targetPath: json['targetPath'] as String? ?? '/',
    url: json['url'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    archivedAt: switch (json['archivedAt']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
  );

  static const fields =
      'id code name description targetPath url createdAt archivedAt';

  final String id;

  /// Часть ссылки после `/go/`; не меняется никогда — ссылка могла уже
  /// уйти в печать.
  final String code;
  final String name;
  final String description;

  /// Экран, на который ведёт ссылка, когда приложение открыто.
  final String targetPath;

  /// Готовая ссылка для раздачи.
  final String url;
  final DateTime createdAt;

  /// Архивный источник уходит из списка по умолчанию, но ссылка работает.
  final DateTime? archivedAt;

  bool get archived => archivedAt != null;
}

/// Воронка источника: клики и что из них вышло. Считается когорта кликов,
/// сделанных за выбранный период.
class LinkSourceStats {
  const LinkSourceStats({
    this.clicks = 0,
    this.clicksAndroid = 0,
    this.clicksIos = 0,
    this.clicksWeb = 0,
    this.reached = 0,
    this.installs = 0,
    this.installsProbable = 0,
    this.opens = 0,
    this.opensProbable = 0,
    this.registrations = 0,
    this.buyers = 0,
    this.purchases = 0,
  });

  factory LinkSourceStats.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return LinkSourceStats(
      clicks: n('clicks'),
      clicksAndroid: n('clicksAndroid'),
      clicksIos: n('clicksIos'),
      clicksWeb: n('clicksWeb'),
      reached: n('reached'),
      installs: n('installs'),
      installsProbable: n('installsProbable'),
      opens: n('opens'),
      opensProbable: n('opensProbable'),
      registrations: n('registrations'),
      buyers: n('buyers'),
      purchases: n('purchases'),
    );
  }

  static const fields =
      'clicks clicksAndroid clicksIos clicksWeb reached installs '
      'installsProbable opens opensProbable registrations buyers purchases';

  static const empty = LinkSourceStats();

  /// Все клики: переходы через браузер и ссылки, открывшие приложение сразу.
  final int clicks;
  final int clicksAndroid;
  final int clicksIos;
  final int clicksWeb;

  /// Устройства, до которых дошёл клик: [installs] + [opens].
  final int reached;

  /// Новые установки, первый запуск которых привязан к клику.
  final int installs;

  /// …из них сопоставленные только по сети и времени (iPhone) — оценка.
  final int installsProbable;

  /// Уже установленное приложение или веб-версия, открытые по клику.
  final int opens;
  final int opensProbable;

  /// Аккаунты, созданные после клика на устройстве, до которого он дошёл.
  final int registrations;

  /// Люди, купившие подписку после клика.
  final int buyers;

  /// Их покупки (с продлениями, без возвратов).
  final int purchases;
}
