import '../../subscription/models/subscription_models.dart';
import 'billing_admin_state.dart';

/// События денежного стола (админки платежей).
sealed class BillingAdminEvent {}

/// Открыть стол: загрузить реквизиты получателя и первую страницу заказов.
class BillingAdminStarted extends BillingAdminEvent {}

/// Перейти на вкладку; данные вкладки подгружаются при первом входе.
class BillingTabSelected extends BillingAdminEvent {
  BillingTabSelected(this.tab);
  final BillingTab tab;
}

/// Сменить фильтр/поиск заказов (список перечитывается с первой страницы).
class OrdersFilterChanged extends BillingAdminEvent {
  OrdersFilterChanged({this.status, this.search, this.clearStatus = false});

  final OrderStatus? status;
  final String? search;

  /// `status == null` — «не менять»; чтобы снять фильтр, ставится этот флаг.
  final bool clearStatus;
}

/// Набор текста в поле поиска (сам поиск — [OrdersFilterChanged]).
class SearchDraftChanged extends BillingAdminEvent {
  SearchDraftChanged(this.text);
  final String text;
}

/// Листать заказы.
class OrdersPageRequested extends BillingAdminEvent {
  OrdersPageRequested(this.offset);
  final int offset;
}

/// Перечитать текущую страницу заказов.
class OrdersRefreshed extends BillingAdminEvent {}

/// Оператор подтвердил оплату заказа.
class OrderConfirmed extends BillingAdminEvent {
  OrderConfirmed(this.orderId);
  final String orderId;
}

/// Оператор отменил заказ.
class OrderCancelledByAdmin extends BillingAdminEvent {
  OrderCancelledByAdmin(this.orderId, {this.reason});
  final String orderId;
  final String? reason;
}

/// Открыть карточку пользователя по email.
class UserLookedUp extends BillingAdminEvent {
  UserLookedUp(this.email);
  final String email;
}

/// Набор email в поле поиска пользователя.
class UserEmailDraftChanged extends BillingAdminEvent {
  UserEmailDraftChanged(this.text);
  final String text;
}

/// Изменение формы ручной выдачи; `null` — поле не трогали.
class GrantFormChanged extends BillingAdminEvent {
  GrantFormChanged({this.kind, this.months, this.note});
  final TariffKind? kind;
  final String? months;
  final String? note;
}

/// Перечитать открытую карточку пользователя (после действия).
class UserRefreshed extends BillingAdminEvent {}

/// Выдать подписку вручную (тот же путь — апгрейд «базовый → с русским»).
class SubscriptionGranted extends BillingAdminEvent {
  SubscriptionGranted({required this.kind, required this.months, this.note});
  final TariffKind kind;
  final int months;
  final String? note;
}

/// Продлить текущую подписку на N месяцев, набор фич прежний.
class SubscriptionExtended extends BillingAdminEvent {
  SubscriptionExtended({required this.months, this.note});
  final int months;
  final String? note;
}

/// Отозвать текущую и отложенные периоды.
class SubscriptionRevoked extends BillingAdminEvent {
  SubscriptionRevoked({this.note});
  final String? note;
}

/// Перечитать журнал операций.
class AuditRefreshed extends BillingAdminEvent {}

/// Набор цены в поле тарифа (сохранение — [TariffPriceCommitted]).
class TariffPriceDraftChanged extends BillingAdminEvent {
  TariffPriceDraftChanged(this.sku, this.text);
  final String sku;
  final String text;
}

/// Сохранить набранную цену тарифа (уход из поля / Enter).
class TariffPriceCommitted extends BillingAdminEvent {
  TariffPriceCommitted(this.sku);
  final String sku;
}

/// Показать/скрыть тариф в витрине.
class TariffActiveToggled extends BillingAdminEvent {
  TariffActiveToggled(this.sku, this.active);
  final String sku;
  final bool active;
}

/// Перечитать список промокодов.
class PromosRefreshed extends BillingAdminEvent {}

/// Изменение формы генерации промокодов; `null` — поле не трогали.
class PromoFormChanged extends BillingAdminEvent {
  PromoFormChanged({
    this.count,
    this.discount,
    this.validUntil,
    this.sku,
    this.clearSku = false,
    this.note,
  });

  final String? count;
  final String? discount;
  final DateTime? validUntil;
  final String? sku;

  /// `sku == null` — «не менять»; чтобы вернуть «все тарифы», ставится флаг.
  final bool clearSku;
  final String? note;
}

/// Сгенерировать пачку промокодов из формы.
class PromoCodesGenerated extends BillingAdminEvent {}

/// Удалить неиспользованный промокод.
class PromoCodeDeleted extends BillingAdminEvent {
  PromoCodeDeleted(this.code);
  final String code;
}

/// Изменение формы реквизитов; `null` — поле не трогали.
class PayeeDraftChanged extends BillingAdminEvent {
  PayeeDraftChanged({
    this.accountNumber,
    this.name,
    this.address,
    this.paymentCode,
    this.purpose,
  });
  final String? accountNumber;
  final String? name;
  final String? address;
  final String? paymentCode;
  final String? purpose;
}

/// Сохранить реквизиты получателя из черновика формы.
class PayeeSaved extends BillingAdminEvent {}
