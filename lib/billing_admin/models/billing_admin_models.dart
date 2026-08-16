/// Модели денежного стола (админки платежей) — зеркало админской части
/// `saobracaj_backend/src/billing/model.rs` и `payment.rs`.
///
/// Заказы, периоды и статус подписки переиспользуют модели пользовательской
/// подписки; здесь только то, что нужно оператору сверх них.
library;

import '../../subscription/models/subscription_models.dart';

/// Карточка пользователя для оператора: подписка, периоды и заказы.
class BillingUser {
  const BillingUser({
    required this.userId,
    required this.email,
    required this.subscription,
    required this.periods,
    required this.orders,
  });

  factory BillingUser.fromJson(Map<String, dynamic> json) => BillingUser(
    userId: json['userId'] as String,
    email: json['email'] as String,
    subscription: SubscriptionStatus.fromJson(
      json['subscription'] as Map<String, dynamic>,
    ),
    periods: [
      for (final raw in json['periods'] as List? ?? const [])
        SubscriptionPeriod.fromJson(raw as Map<String, dynamic>),
    ],
    orders: [
      for (final raw in json['orders'] as List? ?? const [])
        Order.fromJson(raw as Map<String, dynamic>),
    ],
  );

  final String userId;
  final String email;
  final SubscriptionStatus subscription;
  final List<SubscriptionPeriod> periods;
  final List<Order> orders;
}

/// Запись журнала денежных операций: кто, что и когда.
class BillingAuditEntry {
  const BillingAuditEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.actorEmail,
    this.details,
  });

  factory BillingAuditEntry.fromJson(Map<String, dynamic> json) =>
      BillingAuditEntry(
        id: json['id'] as String,
        action: json['action'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        actorEmail: json['actorEmail'] as String?,
        details: json['details'] as String?,
      );

  final String id;
  final String action;
  final DateTime createdAt;

  /// Пусто у действий системы (протухание заказов).
  final String? actorEmail;
  final String? details;
}

/// Тариф глазами оператора: помимо цены — видимость в витрине.
class AdminTariff {
  const AdminTariff({
    required this.sku,
    required this.kind,
    required this.months,
    required this.priceRsd,
    required this.active,
  });

  factory AdminTariff.fromJson(Map<String, dynamic> json) => AdminTariff(
    sku: json['sku'] as String,
    kind: TariffKind.parse(json['kind'] as String?),
    months: (json['months'] as num).toInt(),
    priceRsd: (json['priceRsd'] as num).toInt(),
    active: json['active'] as bool? ?? true,
  );

  final String sku;
  final TariffKind kind;
  final int months;
  final int priceRsd;
  final bool active;
}

/// Получатель платежей — банковские реквизиты оператора, на которые выписаны
/// все уплатницы. Пока [configured] false, заказы идут без реквизитов.
class Payee {
  const Payee({
    required this.accountNumber,
    required this.accountDisplay,
    required this.name,
    this.address,
    required this.paymentCode,
    required this.purpose,
    required this.configured,
  });

  factory Payee.fromJson(Map<String, dynamic> json) => Payee(
    accountNumber: json['accountNumber'] as String? ?? '',
    accountDisplay: json['accountDisplay'] as String? ?? '',
    name: json['name'] as String? ?? '',
    address: json['address'] as String?,
    paymentCode: json['paymentCode'] as String? ?? '289',
    purpose: json['purpose'] as String? ?? '',
    configured: json['configured'] as bool? ?? false,
  );

  static const fields = '''
    accountNumber accountDisplay name address paymentCode purpose configured
  ''';

  final String accountNumber;
  final String accountDisplay;
  final String name;
  final String? address;
  final String paymentCode;
  final String purpose;
  final bool configured;
}

/// Страница заказов админского списка.
class OrdersPage {
  const OrdersPage({required this.items, required this.total});

  final List<Order> items;
  final int total;
}
