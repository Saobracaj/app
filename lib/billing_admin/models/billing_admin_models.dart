/// Модели денежного стола (админки платежей) — зеркало админской части
/// `saobracaj_backend/src/billing/model.rs`.
///
/// Покупки, периоды и статус подписки переиспользуют модели пользовательской
/// подписки; здесь только то, что нужно оператору сверх них.
library;

import '../../subscription/models/subscription_models.dart';

/// Карточка пользователя для оператора: подписка, периоды и покупки.
class BillingUser {
  const BillingUser({
    required this.userId,
    required this.email,
    required this.subscription,
    required this.periods,
    required this.purchases,
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
    purchases: [
      for (final raw in json['purchases'] as List? ?? const [])
        StorePurchase.fromJson(raw as Map<String, dynamic>),
    ],
  );

  final String userId;
  final String email;
  final SubscriptionStatus subscription;
  final List<SubscriptionPeriod> periods;
  final List<StorePurchase> purchases;
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

/// Тариф глазами оператора: цена, видимость в витрине и товары в сторах.
class AdminTariff {
  const AdminTariff({
    required this.sku,
    required this.months,
    required this.priceRsd,
    required this.active,
    required this.appleProductId,
    required this.googleProductId,
    required this.autoRenewing,
  });

  factory AdminTariff.fromJson(Map<String, dynamic> json) => AdminTariff(
    sku: json['sku'] as String,
    months: (json['months'] as num).toInt(),
    priceRsd: (json['priceRsd'] as num).toInt(),
    active: json['active'] as bool? ?? true,
    appleProductId: json['appleProductId'] as String? ?? '',
    googleProductId: json['googleProductId'] as String? ?? '',
    autoRenewing: json['autoRenewing'] as bool? ?? false,
  );

  static const fields =
      'sku months priceRsd active appleProductId googleProductId '
      'autoRenewing';

  final String sku;
  final int months;

  /// Справочная цена: её показывает веб-витрина. Сколько человек заплатит на
  /// самом деле, задано в консолях сторов.
  final int priceRsd;
  final bool active;
  final String appleProductId;
  final String googleProductId;
  final bool autoRenewing;
}

/// Страница покупок админского списка.
class StorePurchasesPage {
  const StorePurchasesPage({required this.items, required this.total});

  final List<StorePurchase> items;
  final int total;
}
