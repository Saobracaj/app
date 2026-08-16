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

/// Заказ: «хочу этот тариф». Пока не оплачен — несёт позив на број, по
/// которому оператор найдёт платёж в банковской выписке.
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
  );

  final String id;
  final String sku;
  final TariffKind kind;
  final int months;
  final int amountRsd;
  final OrderStatus status;
  final String referenceDisplay;
  final DateTime createdAt;
  final DateTime paymentDueAt;

  bool get isPending => status == OrderStatus.pending;
}

/// Текущее состояние подписки пользователя.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.active,
    this.kind,
    this.endsAt,
    this.daysLeft,
    this.remindersEnabled = true,
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
    );
  }

  final bool active;
  final TariffKind? kind;
  final DateTime? endsAt;
  final int? daysLeft;
  final bool remindersEnabled;

  /// Пора ли предложить продлить: за 14 и за 3 дня до конца — те же пороги, на
  /// которых бэкенд шлёт письма-напоминания.
  bool get shouldOfferRenewal =>
      active && daysLeft != null && daysLeft! <= 14;

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
  });

  factory SubscriptionPeriod.fromJson(Map<String, dynamic> json) =>
      SubscriptionPeriod(
        startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
        endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
        kind: json['tariffKind'] == null
            ? null
            : TariffKind.parse(json['tariffKind'] as String?),
        revoked: json['revokedAt'] != null,
      );

  final DateTime startsAt;
  final DateTime endsAt;
  final TariffKind? kind;
  final bool revoked;
}
