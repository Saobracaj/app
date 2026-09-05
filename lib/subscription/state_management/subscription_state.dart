import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/subscription_models.dart';

part 'subscription_state.freezed.dart';

/// Состояние раздела «Подписка» и витрины тарифов — один Bloc обслуживает оба
/// экрана: и там и там нужны и каталог, и текущая подписка.
@freezed
abstract class SubscriptionState with _$SubscriptionState {
  const factory SubscriptionState({
    @Default(true) bool inProgress,
    @Default(<Tariff>[]) List<Tariff> tariffs,
    @Default(SubscriptionStatus.none) SubscriptionStatus subscription,
    @Default(<StorePurchase>[]) List<StorePurchase> purchases,
    @Default(<SubscriptionPeriod>[]) List<SubscriptionPeriod> periods,
    String? errorMessage,

    /// Одноразовое сообщение об успехе (снэкбар) — например, подписка
    /// активирована после покупки.
    String? infoMessage,

    // --- сторона стора
    /// Цены стора по идентификатору товара. Пусто в вебе и пока стор не
    /// ответил — витрина тогда показывает справочную цену в динарах.
    @Default(<String, StoreProduct>{}) Map<String, StoreProduct> storeProducts,

    /// Можно ли платить прямо сейчас: есть плагин, стор доступен, товары
    /// заведены. В вебе — всегда `false`.
    @Default(false) bool storeAvailable,

    /// SKU, окно оплаты которого сейчас открыто.
    String? purchasingSku,

    /// Идёт «восстановить покупки».
    @Default(false) bool restoring,

    /// Чек уже у бэкенда, ждём подтверждения права.
    @Default(false) bool redeeming,
  }) = _SubscriptionState;

  const SubscriptionState._();

  /// Витрина показывает один ряд сроков: тариф один, пропуска различаются
  /// только длиной — по возрастанию срока.
  List<Tariff> get offeredTariffs =>
      [...tariffs]..sort((a, b) => a.months.compareTo(b.months));

  /// Пропуск, который витрина выделяет: трёхмесячный, а без него — самый
  /// длинный. `null` без каталога.
  Tariff? get recommendedTariff {
    final offered = offeredTariffs;
    if (offered.isEmpty) return null;
    for (final tariff in offered) {
      if (tariff.recommended) return tariff;
    }
    return offered.last;
  }

  /// Цена тарифа в сторе, если стор её сообщил.
  StoreProduct? storeProductFor(Tariff tariff, StorePlatform? platform) {
    if (platform == null) return null;
    final id = tariff.productIdFor(platform);
    return id.isEmpty ? null : storeProducts[id];
  }

  /// Месячный пропуск — база, относительно которой считается экономия длинных
  /// сроков. `null`, если каталог такого срока не содержит.
  Tariff? get monthlyTariff {
    for (final tariff in offeredTariffs) {
      if (tariff.months == 1) return tariff;
    }
    return null;
  }

  /// Насколько [tariff] дешевле, чем тот же срок помесячными платежами, в
  /// процентах. `null`, когда сравнивать не с чем (нет месячного тарифа или это
  /// он сам).
  ///
  /// Считается по ценам стора, когда они известны: там цена в валюте
  /// покупателя, и справочные динары могут давать другую пропорцию.
  int? savingPercent(Tariff tariff, [StorePlatform? platform]) {
    final monthly = monthlyTariff;
    if (monthly == null || tariff.months <= 1) return null;
    final monthlyPrice = _price(monthly, platform);
    final price = _price(tariff, platform);
    final asMonthly = monthlyPrice * tariff.months;
    if (asMonthly <= 0) return null;
    return ((1 - price / asMonthly) * 100).round();
  }

  /// Сколько человек оставляет себе, выбрав [tariff] вместо помесячной оплаты,
  /// в справочных динарах. `null`, когда сравнивать не с чем.
  int? savingRsd(Tariff tariff) {
    final monthly = monthlyTariff;
    if (monthly == null || tariff.months <= 1) return null;
    return monthly.priceRsd * tariff.months - tariff.priceRsd;
  }

  double _price(Tariff tariff, StorePlatform? platform) =>
      storeProductFor(tariff, platform)?.rawPrice ?? tariff.priceRsd.toDouble();

  /// Есть ли среди предлагаемых тарифов автопродлеваемый — от этого зависит,
  /// показывать ли условия автопродления, которых требуют оба стора.
  bool get hasAutoRenewingTariff =>
      offeredTariffs.any((tariff) => tariff.autoRenewing);

  /// Идёт ли сейчас платёжная операция — на это время кнопки покупки заперты.
  bool get busy => purchasingSku != null || restoring || redeeming;
}
