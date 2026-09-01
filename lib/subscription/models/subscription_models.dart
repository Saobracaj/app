/// Модели подписки и покупок — зеркало `saobracaj_backend/src/billing/model.rs`.
///
/// Простые неизменяемые классы с `fromJson`: тут нет ни копирования полей, ни
/// сравнения по значению, ради которых стоило бы тянуть freezed.
library;

/// Семейство тарифа. Разница между ними — объём контента (конспекты и
/// объяснения на русском), а не наценка за язык.
enum TariffKind {
  basic,
  russian;

  static TariffKind parse(String? raw) =>
      raw?.toUpperCase() == 'RUSSIAN' ? TariffKind.russian : TariffKind.basic;
}

/// Магазин, через который прошла оплата.
enum StorePlatform {
  apple,
  google;

  static StorePlatform? parse(String? raw) => switch (raw?.toUpperCase()) {
    'APPLE' => StorePlatform.apple,
    'GOOGLE' => StorePlatform.google,
    _ => null,
  };

  /// Имя в GraphQL-энуме.
  String get wire => name.toUpperCase();
}

/// Состояние покупки по данным магазина.
enum StorePurchaseStatus {
  active,
  expired,
  refunded;

  static StorePurchaseStatus parse(String? raw) => switch (raw?.toUpperCase()) {
    'EXPIRED' => StorePurchaseStatus.expired,
    'REFUNDED' => StorePurchaseStatus.refunded,
    _ => StorePurchaseStatus.active,
  };
}

/// Покупаемый SKU: семейство × срок.
///
/// Цена в динарах — **справочная**: её показывает веб-витрина, где магазина
/// нет. В приложении цена всегда берётся из стора ([StoreProduct.price]) — там
/// она в валюте покупателя и с местными налогами.
class Tariff {
  const Tariff({
    required this.sku,
    required this.kind,
    required this.months,
    required this.priceRsd,
    required this.appleProductId,
    required this.googleProductId,
    required this.autoRenewing,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) => Tariff(
    sku: json['sku'] as String,
    kind: TariffKind.parse(json['kind'] as String?),
    months: (json['months'] as num).toInt(),
    priceRsd: (json['priceRsd'] as num).toInt(),
    appleProductId: json['appleProductId'] as String? ?? '',
    googleProductId: json['googleProductId'] as String? ?? '',
    autoRenewing: json['autoRenewing'] as bool? ?? false,
  );

  /// GraphQL-выборка полей витрины.
  static const fields =
      'sku kind months priceRsd appleProductId googleProductId autoRenewing';

  final String sku;
  final TariffKind kind;
  final int months;
  final int priceRsd;

  /// Идентификаторы товара в двух сторах — по ним приложение спрашивает у
  /// стора локальную цену и по ним же покупает.
  final String appleProductId;
  final String googleProductId;

  /// Продлевает ли стор подписку сам. Месячные тарифы — да; 6 и 12 месяцев
  /// оплачиваются один раз и просто заканчиваются.
  final bool autoRenewing;

  /// Цена за месяц — для подписи «выгоднее на N%» у длинных сроков.
  double get pricePerMonth => priceRsd / months;

  /// Идентификатор товара в сторе [platform]; пустая строка, если тариф там
  /// не заведён.
  String productIdFor(StorePlatform platform) => switch (platform) {
    StorePlatform.apple => appleProductId,
    StorePlatform.google => googleProductId,
  };
}

/// Товар глазами стора: цена в валюте покупателя, уже отформатированная.
///
/// Собственная модель, а не `ProductDetails` плагина: состояние Bloc'а и тесты
/// не должны зависеть от типа, которого в вебе нет вовсе.
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
  });

  final String id;

  /// Цена как её показывает стор — «1.190,00 RSD», «€9.99». Показываем именно
  /// её: правила обоих сторов требуют цену в валюте покупателя, а пересчитать
  /// её самим мы всё равно не можем.
  final String price;
  final double rawPrice;
  final String currencyCode;
}

/// Покупка в сторе — строка истории и одновременно чек.
class StorePurchase {
  const StorePurchase({
    required this.id,
    required this.platform,
    required this.sku,
    required this.kind,
    required this.months,
    required this.productId,
    required this.transactionId,
    required this.autoRenewing,
    required this.status,
    required this.purchasedAt,
    this.expiresAt,
    this.userEmail,
    this.userId,
  });

  factory StorePurchase.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expiresAt'] as String?;
    return StorePurchase(
      id: json['id'] as String,
      platform: StorePlatform.parse(json['platform'] as String?) ??
          StorePlatform.apple,
      sku: json['sku'] as String,
      kind: TariffKind.parse(json['tariffKind'] as String?),
      months: (json['months'] as num).toInt(),
      productId: json['productId'] as String? ?? '',
      transactionId: json['transactionId'] as String? ?? '',
      autoRenewing: json['autoRenewing'] as bool? ?? false,
      status: StorePurchaseStatus.parse(json['status'] as String?),
      purchasedAt: DateTime.parse(json['purchasedAt'] as String).toLocal(),
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt).toLocal(),
      userEmail: json['userEmail'] as String?,
      userId: json['userId'] as String?,
    );
  }

  /// GraphQL-выборка полей — общая для пользовательских и админских запросов.
  static const fields = '''
    id userId userEmail platform sku tariffKind months productId transactionId
    autoRenewing status purchasedAt expiresAt
  ''';

  final String id;
  final StorePlatform platform;
  final String sku;
  final TariffKind kind;
  final int months;
  final String productId;

  /// Идентификатор платежа в сторе — по нему покупку находят в поддержке.
  final String transactionId;
  final bool autoRenewing;
  final StorePurchaseStatus status;
  final DateTime purchasedAt;

  /// Когда заканчивается право по версии стора; у разовой покупки `null` —
  /// срок там задаёт тариф, а не стор.
  final DateTime? expiresAt;

  /// Покупатель — заполняется в админских выборках.
  final String? userEmail;
  final String? userId;
}

/// Текущее состояние подписки пользователя.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.active,
    this.kind,
    this.endsAt,
    this.daysLeft,
    this.autoRenewing = false,
    this.manageUrl,
    this.platform,
    this.remindersEnabled = true,
    this.featureKeys = const [],
  });

  /// Состояние «подписки нет» — им же инициализируется экран.
  static const none = SubscriptionStatus(active: false);

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final endsAt = json['endsAt'] as String?;
    return SubscriptionStatus(
      active: json['active'] as bool? ?? false,
      kind: json['tariffKind'] == null
          ? null
          : TariffKind.parse(json['tariffKind'] as String?),
      endsAt: endsAt == null ? null : DateTime.parse(endsAt).toLocal(),
      daysLeft: (json['daysLeft'] as num?)?.toInt(),
      autoRenewing: json['autoRenewing'] as bool? ?? false,
      manageUrl: json['manageUrl'] as String?,
      platform: StorePlatform.parse(json['platform'] as String?),
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      featureKeys: [
        for (final k in json['featureKeys'] as List? ?? const []) k as String,
      ],
    );
  }

  /// GraphQL-выборка полей.
  static const fields = '''
    active tariffKind endsAt daysLeft autoRenewing manageUrl platform
    remindersEnabled
  ''';

  final bool active;
  final TariffKind? kind;
  final DateTime? endsAt;
  final int? daysLeft;

  /// Продлевает ли стор подписку сам. Тогда [endsAt] — дата следующего
  /// списания, а не день, когда доступ закончится.
  final bool autoRenewing;

  /// Куда отправить человека управлять подпиской: отменить её можно только в
  /// сторе, который её продал.
  final String? manageUrl;
  final StorePlatform? platform;
  final bool remindersEnabled;

  /// Ключи фич, которые сейчас даёт подписка (админская карточка).
  final List<String> featureKeys;

  /// Пора ли предложить продлить: за 14 и за 3 дня до конца — те же пороги, на
  /// которых бэкенд шлёт письма-напоминания. Автопродлеваемую подписку
  /// продлевать не предлагаем: стор спишет сам.
  bool get shouldOfferRenewal =>
      active && !autoRenewing && daysLeft != null && daysLeft! <= 14;

  /// Срочная плашка — осталось три дня или меньше.
  bool get renewalIsUrgent =>
      shouldOfferRenewal && daysLeft != null && daysLeft! <= 3;
}

/// Период подписки — строка истории «с какого по какое число что действовало».
class SubscriptionPeriod {
  const SubscriptionPeriod({
    required this.startsAt,
    required this.endsAt,
    required this.kind,
    required this.revoked,
    this.fromPurchase = true,
    this.autoRenewing = false,
    this.note,
  });

  factory SubscriptionPeriod.fromJson(Map<String, dynamic> json) =>
      SubscriptionPeriod(
        startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
        endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
        kind: json['tariffKind'] == null
            ? null
            : TariffKind.parse(json['tariffKind'] as String?),
        revoked: json['revokedAt'] != null,
        fromPurchase: (json['source'] as String?)?.toUpperCase() != 'MANUAL',
        autoRenewing: json['autoRenewing'] as bool? ?? false,
        note: json['note'] as String?,
      );

  /// GraphQL-выборка полей.
  static const fields =
      'startsAt endsAt tariffKind revokedAt source autoRenewing note';

  final DateTime startsAt;
  final DateTime endsAt;
  final TariffKind? kind;
  final bool revoked;

  /// Откуда период: из покупки (в сторе или, у старых строк, переводом) или
  /// выдан оператором вручную.
  final bool fromPurchase;
  final bool autoRenewing;

  /// Комментарий оператора (ручные выдачи/продления/отзывы).
  final String? note;
}
