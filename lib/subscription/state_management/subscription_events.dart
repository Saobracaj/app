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

/// Переключить письма-напоминания об окончании подписки.
class RemindersToggled extends SubscriptionEvent {
  RemindersToggled(this.enabled);

  final bool enabled;
}
