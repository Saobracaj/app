import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/subscription_models.dart';

part 'subscription_state.freezed.dart';

/// Состояние раздела «Подписка» и витрины тарифов — один Bloc обслуживает оба
/// экрана: и там и там нужны и каталог, и текущая подписка, и неоплаченный
/// заказ (иначе витрина предложила бы оформить второй заказ на то же самое).
@freezed
abstract class SubscriptionState with _$SubscriptionState {
  const factory SubscriptionState({
    @Default(true) bool inProgress,
    @Default(false) bool submitting,
    @Default(<Tariff>[]) List<Tariff> tariffs,
    @Default(SubscriptionStatus.none) SubscriptionStatus subscription,
    @Default(<Order>[]) List<Order> orders,
    @Default(<SubscriptionPeriod>[]) List<SubscriptionPeriod> periods,
    String? errorMessage,
  }) = _SubscriptionState;

  const SubscriptionState._();

  /// Заказ, который ждёт оплаты, — по нему человек возвращается доплатить,
  /// вместо того чтобы создавать второй.
  Order? get pendingOrder {
    for (final order in orders) {
      if (order.isPending) return order;
    }
    return null;
  }

  /// Прошлые (не ожидающие оплаты) заказы — история.
  List<Order> get pastOrders => [
    for (final order in orders)
      if (!order.isPending) order,
  ];
}
