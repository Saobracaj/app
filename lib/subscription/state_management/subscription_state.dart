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
    @Default(false) bool withRussian,
    String? errorMessage,
  }) = _SubscriptionState;

  const SubscriptionState._();

  /// Витрина показывает один ряд сроков, а не два семейства тарифов: русский —
  /// надбавка ([withRussian]), а не отдельный план. Отсюда и выборка — тарифы
  /// выбранного семейства по возрастанию срока.
  List<Tariff> get offeredTariffs {
    final kind = withRussian ? TariffKind.russian : TariffKind.basic;
    return [
      for (final t in tariffs)
        if (t.kind == kind) t,
    ]..sort((a, b) => a.months.compareTo(b.months));
  }

  /// Месячный тариф выбранного семейства — база, относительно которой считается
  /// экономия длинных сроков. `null`, если каталог такого срока не содержит.
  Tariff? get monthlyTariff {
    for (final tariff in offeredTariffs) {
      if (tariff.months == 1) return tariff;
    }
    return null;
  }

  /// Насколько [tariff] дешевле, чем тот же срок помесячными платежами, в
  /// процентах. `null`, когда сравнивать не с чем (нет месячного тарифа или это
  /// он сам).
  int? savingPercent(Tariff tariff) {
    final monthly = monthlyTariff;
    if (monthly == null || tariff.months <= 1) return null;
    final asMonthly = monthly.priceRsd * tariff.months;
    if (asMonthly <= 0) return null;
    return ((1 - tariff.priceRsd / asMonthly) * 100).round();
  }

  /// Сколько человек оставляет себе, выбрав [tariff] вместо помесячной оплаты.
  int? savingRsd(Tariff tariff) {
    final monthly = monthlyTariff;
    if (monthly == null || tariff.months <= 1) return null;
    return monthly.priceRsd * tariff.months - tariff.priceRsd;
  }

  /// Надбавка за русские материалы на самом длинном сроке — цена, которую видно
  /// у выключенного тумблера. `null`, если пары тарифов для сравнения нет.
  int? get russianAddonRsd {
    Tariff? basic;
    Tariff? russian;
    for (final tariff in tariffs) {
      final longest = tariff.kind == TariffKind.basic ? basic : russian;
      if (longest != null && longest.months >= tariff.months) continue;
      if (tariff.kind == TariffKind.basic) {
        basic = tariff;
      } else {
        russian = tariff;
      }
    }
    if (basic == null || russian == null || basic.months != russian.months) {
      return null;
    }
    return russian.priceRsd - basic.priceRsd;
  }

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
