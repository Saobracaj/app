/// События раздела подписки и витрины тарифов.
sealed class SubscriptionEvent {}

/// Загрузить каталог, подписку, заказы и историю (при открытии экрана и после
/// «повторить» на ошибке).
class SubscriptionRequested extends SubscriptionEvent {}

/// Оформить заказ на выбранный тариф.
class OrderRequested extends SubscriptionEvent {
  OrderRequested(this.sku);

  final String sku;
}

/// Отменить свой неоплаченный заказ.
class OrderCancelled extends SubscriptionEvent {
  OrderCancelled(this.orderId);

  final String orderId;
}

/// Включить/выключить надбавку за русские материалы на витрине. Меняет только
/// то, какие SKU показаны, — ничего не покупает и не трогает локальный флаг
/// `russian_content`.
class RussianAddonToggled extends SubscriptionEvent {
  RussianAddonToggled(this.enabled);

  final bool enabled;
}

/// Переключить письма-напоминания об окончании подписки.
class RemindersToggled extends SubscriptionEvent {
  RemindersToggled(this.enabled);

  final bool enabled;
}
