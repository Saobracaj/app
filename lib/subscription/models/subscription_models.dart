/// Модели подписки и заказов — зеркало `saobracaj_backend/src/billing/model.rs`.
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

/// Статус заказа.
enum OrderStatus {
  pending,
  paid,
  cancelled,
  expired;

  static OrderStatus parse(String? raw) => switch (raw?.toUpperCase()) {
    'PAID' => OrderStatus.paid,
    'CANCELLED' => OrderStatus.cancelled,
    'EXPIRED' => OrderStatus.expired,
    _ => OrderStatus.pending,
  };
}

/// Покупаемый SKU: семейство × срок. Цена приходит с сервера — её меняют без
/// релиза приложения.
class Tariff {
  const Tariff({
    required this.sku,
    required this.kind,
    required this.months,
    required this.priceRsd,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) => Tariff(
    sku: json['sku'] as String,
    kind: TariffKind.parse(json['kind'] as String?),
    months: (json['months'] as num).toInt(),
    priceRsd: (json['priceRsd'] as num).toInt(),
  );

  final String sku;
  final TariffKind kind;
  final int months;
  final int priceRsd;

  /// Цена за месяц — для подписи «выгоднее на N%» у длинных сроков.
  double get pricePerMonth => priceRsd / months;
}

/// Платёжные реквизиты заказа в форме сербской уплатницы — зеркало
/// `PaymentSlip` бэкенда. Приходят только у неоплаченного заказа и только после
/// того, как оператор ввёл реквизиты получателя; до того `Order.payment == null`
/// и карточка заказа показывает один позив на број.
class PaymentSlip {
  const PaymentSlip({
    required this.payer,
    required this.purpose,
    required this.payeeName,
    this.payeeAddress,
    required this.paymentCode,
    required this.currency,
    required this.amountRsd,
    required this.amountDisplay,
    required this.payeeAccount,
    required this.model,
    required this.reference,
    required this.referenceDisplay,
    required this.ipsQrText,
    required this.ipsQrUrl,
  });

  factory PaymentSlip.fromJson(Map<String, dynamic> json) => PaymentSlip(
    payer: json['payer'] as String? ?? '',
    purpose: json['purpose'] as String? ?? '',
    payeeName: json['payeeName'] as String? ?? '',
    payeeAddress: json['payeeAddress'] as String?,
    paymentCode: json['paymentCode'] as String? ?? '',
    currency: json['currency'] as String? ?? 'RSD',
    amountRsd: (json['amountRsd'] as num?)?.toInt() ?? 0,
    amountDisplay: json['amountDisplay'] as String? ?? '',
    payeeAccount: json['payeeAccount'] as String? ?? '',
    model: json['model'] as String? ?? '97',
    reference: json['reference'] as String? ?? '',
    referenceDisplay: json['referenceDisplay'] as String? ?? '',
    ipsQrText: json['ipsQrText'] as String? ?? '',
    ipsQrUrl: json['ipsQrUrl'] as String? ?? '',
  );

  /// GraphQL-выборка полей — общая для пользовательских и админских запросов.
  static const fields = '''
    payer purpose payeeName payeeAddress paymentCode currency amountRsd
    amountDisplay payeeAccount model reference referenceDisplay ipsQrText
    ipsQrUrl
  ''';

  /// «Уплатилац».
  final String payer;

  /// «Сврха уплате».
  final String purpose;

  /// «Прималац» — имя и адрес.
  final String payeeName;
  final String? payeeAddress;

  /// «Шифра плаћања».
  final String paymentCode;
  final String currency;
  final int amountRsd;

  /// Сумма как на бланке: `3.490,00`.
  final String amountDisplay;

  /// «Рачун примаоца» в виде `BBB-AAAAAAAAAAAAA-KK`.
  final String payeeAccount;

  /// «Модел» — всегда 97.
  final String model;

  /// «Позив на број (одобрење)» — только цифры.
  final String reference;
  final String referenceDisplay;

  /// Текст IPS QR (стандарт НБС) — рисуем QR прямо в приложении.
  final String ipsQrText;

  /// Тот же QR как PNG по ссылке (его же вставляет письмо).
  final String ipsQrUrl;

  /// «Прималац» одной строкой — для копирования и компактных списков.
  String get payeeLine => payeeAddress == null || payeeAddress!.isEmpty
      ? payeeName
      : '$payeeName, $payeeAddress';
}

/// Заказ: «хочу этот тариф». Пока не оплачен — несёт позив на број, по
/// которому оператор найдёт платёж в банковской выписке, и (когда оператор ввёл
/// реквизиты) уплатницу с IPS QR.
class Order {
  const Order({
    required this.id,
    required this.sku,
    required this.kind,
    required this.months,
    required this.amountRsd,
    required this.status,
    required this.referenceDisplay,
    required this.createdAt,
    required this.paymentDueAt,
    this.payment,
    this.userEmail,
    this.userId,
    this.paidAt,
    this.promoCode,
    this.discountPercent,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    sku: json['sku'] as String,
    kind: TariffKind.parse(json['tariffKind'] as String?),
    months: (json['months'] as num).toInt(),
    amountRsd: (json['amountRsd'] as num).toInt(),
    status: OrderStatus.parse(json['status'] as String?),
    referenceDisplay: json['referenceDisplay'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    paymentDueAt: DateTime.parse(json['paymentDueAt'] as String).toLocal(),
    payment: json['payment'] == null
        ? null
        : PaymentSlip.fromJson(json['payment'] as Map<String, dynamic>),
    userEmail: json['userEmail'] as String?,
    userId: json['userId'] as String?,
    paidAt: json['paidAt'] == null
        ? null
        : DateTime.parse(json['paidAt'] as String).toLocal(),
    promoCode: json['promoCode'] as String?,
    discountPercent: (json['discountPercent'] as num?)?.toInt(),
  );

  /// GraphQL-выборка полей заказа вместе с уплатницей.
  static const fields =
      '''
    id userId userEmail sku tariffKind months amountRsd status referenceDisplay
    createdAt paymentDueAt paidAt promoCode discountPercent
    payment { ${PaymentSlip.fields} }
  ''';

  final String id;
  final String sku;
  final TariffKind kind;
  final int months;
  final int amountRsd;
  final OrderStatus status;
  final String referenceDisplay;
  final DateTime createdAt;
  final DateTime paymentDueAt;

  /// Уплатница с IPS QR; `null`, пока заказ не оплачиваем или реквизиты не
  /// введены.
  final PaymentSlip? payment;

  /// Покупатель — заполняется в админских выборках (в своих запросах это
  /// сам вызывающий).
  final String? userEmail;
  final String? userId;
  final DateTime? paidAt;

  /// Промокод, применённый при оформлении; [amountRsd] уже со скидкой.
  final String? promoCode;
  final int? discountPercent;

  bool get isPending => status == OrderStatus.pending;
}

/// Что даёт применённый промокод — ответ `checkPromoCode`. Скидка и (если
/// код привязан к тарифу) SKU, к которому он применим.
class PromoCodeInfo {
  const PromoCodeInfo({
    required this.code,
    required this.discountPercent,
    this.sku,
    required this.validUntil,
  });

  factory PromoCodeInfo.fromJson(Map<String, dynamic> json) => PromoCodeInfo(
    code: json['code'] as String,
    discountPercent: (json['discountPercent'] as num).toInt(),
    sku: json['sku'] as String?,
    validUntil: DateTime.parse(json['validUntil'] as String).toLocal(),
  );

  final String code;
  final int discountPercent;

  /// Единственный тариф, на который действует код; `null` — на все.
  final String? sku;
  final DateTime validUntil;

  bool appliesTo(Tariff tariff) => sku == null || sku == tariff.sku;

  /// Цена [tariff] с применённой скидкой — то же округление, что на бэкенде
  /// (`discounted_amount`): до ближайшего динара, но не ниже одного.
  int discountedPrice(Tariff tariff) {
    if (discountPercent >= 100) return 0;
    final amount = (tariff.priceRsd * (100 - discountPercent) + 50) ~/ 100;
    return amount < 1 ? 1 : amount;
  }
}

/// Текущее состояние подписки пользователя.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.active,
    this.kind,
    this.endsAt,
    this.daysLeft,
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
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      featureKeys: [
        for (final k in json['featureKeys'] as List? ?? const []) k as String,
      ],
    );
  }

  final bool active;
  final TariffKind? kind;
  final DateTime? endsAt;
  final int? daysLeft;
  final bool remindersEnabled;

  /// Ключи фич, которые сейчас даёт подписка (админская карточка).
  final List<String> featureKeys;

  /// Пора ли предложить продлить: за 14 и за 3 дня до конца — те же пороги, на
  /// которых бэкенд шлёт письма-напоминания.
  bool get shouldOfferRenewal => active && daysLeft != null && daysLeft! <= 14;

  /// Срочная плашка — осталось три дня или меньше.
  bool get renewalIsUrgent => active && daysLeft != null && daysLeft! <= 3;
}

/// Период подписки — строка истории «с какого по какое число что действовало».
class SubscriptionPeriod {
  const SubscriptionPeriod({
    required this.startsAt,
    required this.endsAt,
    required this.kind,
    required this.revoked,
    this.fromOrder = true,
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
        fromOrder: (json['source'] as String?)?.toUpperCase() != 'MANUAL',
        note: json['note'] as String?,
      );

  final DateTime startsAt;
  final DateTime endsAt;
  final TariffKind? kind;
  final bool revoked;

  /// Откуда период: из оплаченного заказа или выдан оператором вручную.
  final bool fromOrder;

  /// Комментарий оператора (ручные выдачи/продления/отзывы).
  final String? note;
}
