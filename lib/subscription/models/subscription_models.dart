/// Модели подписки и покупок — зеркало `saobracaj_backend/src/billing/model.rs`.
///
/// Простые неизменяемые классы с `fromJson`: тут нет ни копирования полей, ни
/// сравнения по значению, ради которых стоило бы тянуть freezed.
library;

/// Магазин, через который прошла оплата. [lava] — не магазин, а платёжный
/// посредник lava.top, через который сайт принимает российские карты в рублях;
/// для бэкенда это такая же «платформа»: один платёж — один период.
enum StorePlatform {
  apple,
  google,
  lava;

  static StorePlatform? parse(String? raw) => switch (raw?.toUpperCase()) {
    'APPLE' => StorePlatform.apple,
    'GOOGLE' => StorePlatform.google,
    'LAVA' => StorePlatform.lava,
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

/// Покупаемый SKU — пропуск Premium на 1, 3 или 12 месяцев. Тариф один: все
/// пропуска открывают одно и то же (весь премиум-слой, русские материалы
/// включены) и различаются только сроком и ценой.
///
/// Цена в динарах — **справочная**: её показывает веб-витрина, где магазина
/// нет. В приложении цена всегда берётся из стора ([StoreProduct.price]) — там
/// она в валюте покупателя и с местными налогами.
class Tariff {
  const Tariff({
    required this.sku,
    required this.months,
    required this.priceRsd,
    required this.appleProductId,
    required this.googleProductId,
    required this.autoRenewing,
    this.priceRub = 0,
    this.lavaAvailable = false,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) => Tariff(
    sku: json['sku'] as String,
    months: (json['months'] as num).toInt(),
    priceRsd: (json['priceRsd'] as num).toInt(),
    appleProductId: json['appleProductId'] as String? ?? '',
    googleProductId: json['googleProductId'] as String? ?? '',
    autoRenewing: json['autoRenewing'] as bool? ?? false,
    priceRub: (json['priceRub'] as num?)?.toInt() ?? 0,
    lavaAvailable: json['lavaAvailable'] as bool? ?? false,
  );

  /// GraphQL-выборка полей витрины.
  static const fields =
      'sku months priceRsd appleProductId googleProductId autoRenewing '
      'priceRub lavaAvailable';

  final String sku;
  final int months;
  final int priceRsd;

  /// Фиксированная цена в рублях для оплаты российской картой на сайте
  /// (через lava.top). Курсом не пересчитывается.
  final int priceRub;

  /// Можно ли прямо сейчас оплатить этот тариф рублями: оффер на lava.top
  /// заведён, цена задана, у бэкенда есть ключ. Только для веба.
  final bool lavaAvailable;

  /// Идентификаторы товара в двух сторах — по ним приложение спрашивает у
  /// стора локальную цену и по ним же покупает.
  final String appleProductId;
  final String googleProductId;

  /// Продлевает ли стор подписку сам. Месячный пропуск — да; 3 и 12 месяцев
  /// оплачиваются один раз и просто заканчиваются.
  final bool autoRenewing;

  /// Пропуск, который витрина выделяет как «самый популярный»: три месяца —
  /// обычное окно подготовки (курс теории плюс экзамен).
  bool get recommended => months == 3;

  /// Цена за месяц — для подписи «выгоднее на N%» у длинных сроков.
  double get pricePerMonth => priceRsd / months;

  /// Идентификатор товара в сторе [platform]; пустая строка, если тариф там
  /// не заведён.
  String productIdFor(StorePlatform platform) => switch (platform) {
    StorePlatform.apple => appleProductId,
    StorePlatform.google => googleProductId,
    StorePlatform.lava => '',
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
      platform:
          StorePlatform.parse(json['platform'] as String?) ??
          StorePlatform.apple,
      sku: json['sku'] as String,
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
    id userId userEmail platform sku months productId transactionId
    autoRenewing status purchasedAt expiresAt
  ''';

  final String id;
  final StorePlatform platform;
  final String sku;
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

/// Активная покупка в сторе, которой человек обязан действующим правом.
/// Когда активных покупок несколько (год поверх месячной подписки), берём
/// ту, чей тип совпадает с тем, что бэкенд назвал действующим правом. У
/// права, выданного оператором, покупки нет — тогда `null`.
StorePurchase? activePurchaseOf(
  SubscriptionStatus status,
  List<StorePurchase> purchases,
) {
  final active = purchases.where((p) => p.status == StorePurchaseStatus.active);
  return active
          .where((p) => p.autoRenewing == status.autoRenewing)
          .firstOrNull ??
      active.firstOrNull;
}

/// Покупка, за которую стор продолжит списывать деньги: живая
/// автопродлеваемая подписка. Она есть и тогда, когда цепочка периодов
/// заканчивается разовым пропуском (месячная подписка продлевается за ним) —
/// в этом случае экран обязан сказать об этом и дать до неё добраться.
StorePurchase? renewingPurchaseOf(List<StorePurchase> purchases) => purchases
    .where((p) => p.autoRenewing && p.status == StorePurchaseStatus.active)
    .firstOrNull;

/// Текущее состояние подписки пользователя.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.active,
    this.endsAt,
    this.daysLeft,
    this.autoRenewing = false,
    this.manageUrl,
    this.platform,
    this.remindersEnabled = true,
    this.featureKeys = const [],
    this.lavaSubscription,
    this.purchaseBlockedUntil,
  });

  /// Состояние «подписки нет» — им же инициализируется экран.
  static const none = SubscriptionStatus(active: false);

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final endsAt = json['endsAt'] as String?;
    final blockedUntil = json['purchaseBlockedUntil'] as String?;
    final lava = json['lavaSubscription'] as Map<String, dynamic>?;
    return SubscriptionStatus(
      active: json['active'] as bool? ?? false,
      endsAt: endsAt == null ? null : DateTime.parse(endsAt).toLocal(),
      daysLeft: (json['daysLeft'] as num?)?.toInt(),
      autoRenewing: json['autoRenewing'] as bool? ?? false,
      manageUrl: json['manageUrl'] as String?,
      platform: StorePlatform.parse(json['platform'] as String?),
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      featureKeys: [
        for (final k in json['featureKeys'] as List? ?? const []) k as String,
      ],
      lavaSubscription: lava == null ? null : LavaSubscription.fromJson(lava),
      purchaseBlockedUntil: blockedUntil == null
          ? null
          : DateTime.parse(blockedUntil).toLocal(),
    );
  }

  /// GraphQL-выборка полей.
  static const fields =
      '''
    active endsAt daysLeft autoRenewing manageUrl platform
    remindersEnabled purchaseBlockedUntil
    lavaSubscription { ${LavaSubscription.fields} }
  ''';

  final bool active;
  final DateTime? endsAt;
  final int? daysLeft;

  /// Продлевает ли стор подписку сам. Тогда [endsAt] — дата следующего
  /// списания, а не день, когда доступ закончится.
  final bool autoRenewing;

  /// Куда отправить человека управлять подпиской: отменить её можно только в
  /// сторе, который её продал. Есть всегда, когда у аккаунта живая
  /// автопродлеваемая покупка, — и когда поверх неё куплен разовый пропуск
  /// ([autoRenewing] тогда `false`), и когда доступ отозван оператором.
  final String? manageUrl;
  final StorePlatform? platform;
  final bool remindersEnabled;

  /// Ключи фич, которые сейчас даёт подписка (админская карточка).
  final List<String> featureKeys;

  /// Действующая подписка через lava.top (оплата рублями на сайте) — пока
  /// она продлевается или, отменённая, ещё не истекла. Ею управляют прямо в
  /// приложении: следующее списание, сумма, отмена.
  final LavaSubscription? lavaSubscription;

  /// До какой даты нельзя оформить новую подписку или пропуск: пока действует
  /// подписка lava.top (в том числе отменённая). Бэкенд отклоняет такие
  /// заказы тем же правилом.
  final DateTime? purchaseBlockedUntil;

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
    required this.revoked,
    this.fromPurchase = true,
    this.autoRenewing = false,
    this.note,
  });

  factory SubscriptionPeriod.fromJson(Map<String, dynamic> json) =>
      SubscriptionPeriod(
        startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
        endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
        revoked: json['revokedAt'] != null,
        fromPurchase: (json['source'] as String?)?.toUpperCase() != 'MANUAL',
        autoRenewing: json['autoRenewing'] as bool? ?? false,
        note: json['note'] as String?,
      );

  /// GraphQL-выборка полей.
  static const fields = 'startsAt endsAt revokedAt source autoRenewing note';

  final DateTime startsAt;
  final DateTime endsAt;
  final bool revoked;

  /// Откуда период: из покупки (в сторе или, у старых строк, переводом) или
  /// выдан оператором вручную.
  final bool fromPurchase;
  final bool autoRenewing;

  /// Комментарий оператора (ручные выдачи/продления/отзывы).
  final String? note;
}

/// Подписка через lava.top глазами раздела «Подписка»: что и когда спишется,
/// отменена ли и до какого числа действует оплаченный период.
class LavaSubscription {
  const LavaSubscription({
    required this.contractId,
    required this.sku,
    required this.months,
    required this.priceRub,
    required this.cancelled,
    required this.endsAt,
    this.nextChargeAt,
  });

  factory LavaSubscription.fromJson(Map<String, dynamic> json) {
    final nextChargeAt = json['nextChargeAt'] as String?;
    return LavaSubscription(
      contractId: json['contractId'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      months: (json['months'] as num?)?.toInt() ?? 1,
      priceRub: (json['priceRub'] as num?)?.toInt() ?? 0,
      cancelled: json['cancelled'] as bool? ?? false,
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      nextChargeAt: nextChargeAt == null
          ? null
          : DateTime.parse(nextChargeAt).toLocal(),
    );
  }

  /// GraphQL-выборка полей.
  static const fields =
      'contractId sku months priceRub cancelled endsAt nextChargeAt';

  /// Родительский контракт lava.top — его называет отмена.
  final String contractId;
  final String sku;
  final int months;

  /// Сумма ежемесячного списания в рублях.
  final int priceRub;

  /// Отменена: списаний больше не будет, доступ — до [endsAt].
  final bool cancelled;

  /// До какого числа действует оплаченный доступ.
  final DateTime endsAt;

  /// Дата следующего списания; `null` после отмены.
  final DateTime? nextChargeAt;
}

/// Состояние счёта (контракта) lava.top, созданного для покупки.
enum LavaInvoiceStatus {
  pending,
  paid,
  failed;

  static LavaInvoiceStatus parse(String? raw) => switch (raw?.toUpperCase()) {
    'PAID' => LavaInvoiceStatus.paid,
    'FAILED' => LavaInvoiceStatus.failed,
    _ => LavaInvoiceStatus.pending,
  };
}

/// Счёт lava.top: куда отправить платить и оплачен ли уже.
class LavaInvoice {
  const LavaInvoice({
    required this.id,
    required this.sku,
    required this.status,
    this.paymentUrl,
    this.amountRub = 0,
  });

  factory LavaInvoice.fromJson(Map<String, dynamic> json) => LavaInvoice(
    id: json['id'] as String,
    sku: json['sku'] as String? ?? '',
    status: LavaInvoiceStatus.parse(json['status'] as String?),
    paymentUrl: json['paymentUrl'] as String?,
    amountRub: (json['amountRub'] as num?)?.toInt() ?? 0,
  );

  /// GraphQL-выборка полей.
  static const fields = 'id sku status paymentUrl amountRub';

  /// Идентификатор контракта — он же `invoiceId` в адресе возврата.
  final String id;
  final String sku;
  final LavaInvoiceStatus status;

  /// Страница оплаты lava.top; `null`, когда счёт уже оплачен.
  final String? paymentUrl;
  final int amountRub;
}
