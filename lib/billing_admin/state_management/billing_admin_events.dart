import '../../subscription/models/subscription_models.dart';
import 'billing_admin_state.dart';

/// События денежного стола (админки платежей).
sealed class BillingAdminEvent {}

/// Открыть стол: загрузить первую страницу покупок.
class BillingAdminStarted extends BillingAdminEvent {}

/// Перейти на вкладку; данные вкладки подгружаются при первом входе.
class BillingTabSelected extends BillingAdminEvent {
  BillingTabSelected(this.tab);
  final BillingTab tab;
}

/// Сменить фильтр/поиск покупок (список перечитывается с первой страницы).
class PurchasesFilterChanged extends BillingAdminEvent {
  PurchasesFilterChanged({
    this.platform,
    this.search,
    this.clearPlatform = false,
  });

  final StorePlatform? platform;
  final String? search;

  /// `platform == null` — «не менять»; чтобы снять фильтр, ставится этот флаг.
  final bool clearPlatform;
}

/// Набор текста в поле поиска (сам поиск — [PurchasesFilterChanged]).
class SearchDraftChanged extends BillingAdminEvent {
  SearchDraftChanged(this.text);
  final String text;
}

/// Листать покупки.
class PurchasesPageRequested extends BillingAdminEvent {
  PurchasesPageRequested(this.offset);
  final int offset;
}

/// Перечитать текущую страницу покупок.
class PurchasesRefreshed extends BillingAdminEvent {}

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

/// Показать/скрыть тариф в веб-витрине.
class TariffActiveToggled extends BillingAdminEvent {
  TariffActiveToggled(this.sku, this.active);
  final String sku;
  final bool active;
}

