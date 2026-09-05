import '../data/store_purchase_service.dart';

/// События раздела подписки и витрины тарифов.
sealed class SubscriptionEvent {}

/// Загрузить каталог, цены стора, подписку и историю (при открытии экрана и
/// после «повторить» на ошибке).
class SubscriptionRequested extends SubscriptionEvent {}

/// Купить выбранный тариф — открывает окно оплаты стора.
class PurchaseRequested extends SubscriptionEvent {
  PurchaseRequested(this.sku);

  final String sku;
}

/// «Восстановить покупки»: попросить стор перевыдать чеки. Нужно после
/// переустановки и при входе в аккаунт на новом устройстве.
class PurchasesRestoreRequested extends SubscriptionEvent {}

/// Стор прислал чек (в ответ на покупку, восстановление или сам). Событие
/// внутреннее — его добавляет подписка Bloc'а на очередь покупок.
class StorePurchaseReceived extends SubscriptionEvent {
  StorePurchaseReceived(this.event);

  final StorePurchaseEvent event;
}

/// Переключить письма-напоминания об окончании подписки.
class RemindersToggled extends SubscriptionEvent {
  RemindersToggled(this.enabled);

  final bool enabled;
}
