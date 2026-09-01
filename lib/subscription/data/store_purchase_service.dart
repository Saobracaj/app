import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:injectable/injectable.dart';

import '../models/subscription_models.dart';

/// Что случилось с покупкой в сторе.
enum StorePurchaseOutcome {
  /// Оплачено — можно нести чек на бэкенд.
  purchased,

  /// Восстановлено («Restore purchases» или переустановка).
  restored,

  /// Стор ждёт — отложенный платёж (родительский контроль, оплата в кассе).
  /// Ничего не открываем: доступ появится, когда деньги дойдут.
  pending,

  /// Человек закрыл окно оплаты. Не ошибка.
  canceled,

  /// Стор отказал.
  failed,
}

/// Событие из очереди покупок стора, уже без типов плагина.
class StorePurchaseEvent {
  StorePurchaseEvent({
    required this.productId,
    required this.receipt,
    required this.outcome,
    this.errorMessage,
    PurchaseDetails? details,
  }) : _details = details;

  final String productId;

  /// Ключ, по которому бэкенд спросит стор о покупке: на iOS — идентификатор
  /// транзакции, на Android — purchase token.
  final String receipt;
  final StorePurchaseOutcome outcome;
  final String? errorMessage;

  /// Исходная покупка плагина — её нужно вернуть в [StorePurchaseService.complete].
  final PurchaseDetails? _details;

  bool get isPaid =>
      outcome == StorePurchaseOutcome.purchased ||
      outcome == StorePurchaseOutcome.restored;
}

/// Покупки через App Store и Google Play.
///
/// Обёртка вокруг `in_app_purchase` с двумя обязанностями сверх плагина.
///
/// Первая — **не трогать плагин там, где его нет**. Веб-реализации у него не
/// существует, и `InAppPurchase.instance` в вебе бросает; поэтому доступ к
/// инстансу идёт только через [_iap], и каждый метод сначала смотрит на
/// [isSupported]. Веб-сборка от этого не падает, а показывает «оформить можно
/// в приложении».
///
/// Вторая — **порядок подтверждения**. Покупка подтверждается стору
/// ([complete]) только после того, как бэкенд записал право: неподтверждённую
/// покупку Google возвращает покупателю через трое суток, и это правильный
/// исход, если наш сервер её так и не увидел. Обратный порядок молча съел бы
/// деньги.
@lazySingleton
class StorePurchaseService {
  StorePurchaseService();

  /// Плагин доступен только в мобильных сборках. Проверяем платформу, а не
  /// `kIsWeb`: на десктопе (и в тестах на VM) стора тоже нет.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Магазин, чьи товары показывает эта сборка.
  StorePlatform? get platform {
    if (!isSupported) return null;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? StorePlatform.apple
        : StorePlatform.google;
  }

  InAppPurchase get _iap => InAppPurchase.instance;

  /// Готов ли стор принимать оплату прямо сейчас (в симуляторе, на устройстве
  /// без аккаунта или при запрете покупок — нет).
  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _iap.isAvailable();
    } catch (e) {
      debugPrint('store: isAvailable failed: $e');
      return false;
    }
  }

  /// Цены товаров в валюте покупателя. Неизвестные стору идентификаторы просто
  /// не возвращаются — витрина покажет справочную цену.
  Future<List<StoreProduct>> products(Set<String> ids) async {
    if (!isSupported || ids.isEmpty) return const [];
    final response = await _iap.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('store: products not found: ${response.notFoundIDs}');
    }
    return [
      for (final p in response.productDetails)
        StoreProduct(
          id: p.id,
          price: p.price,
          rawPrice: p.rawPrice,
          currencyCode: p.currencyCode,
        ),
    ];
  }

  /// Очередь покупок стора: сюда приходит и результат [buy], и всё, что стор
  /// прислал сам — восстановление, отложенный платёж, покупка, сделанная на
  /// другом устройстве.
  Stream<StorePurchaseEvent> get purchases {
    if (!isSupported) return const Stream.empty();
    return _iap.purchaseStream.expand(
      (list) => list.map(_toEvent),
    );
  }

  /// Открыть окно оплаты. [autoRenewing] выбирает тип покупки: подписка
  /// (месяц) не потребляется, разовый доступ на 6/12 месяцев — потребляется,
  /// иначе его нельзя было бы купить второй раз.
  Future<void> buy({
    required String productId,
    required bool autoRenewing,
  }) async {
    if (!isSupported) return;
    final response = await _iap.queryProductDetails({productId});
    final details = response.productDetails
        .where((p) => p.id == productId)
        .firstOrNull;
    if (details == null) {
      throw StateError('store product $productId is not available');
    }
    final param = PurchaseParam(productDetails: details);
    if (autoRenewing) {
      await _iap.buyNonConsumable(purchaseParam: param);
    } else {
      await _iap.buyConsumable(purchaseParam: param);
    }
  }

  /// «Восстановить покупки»: стор перевыдаёт чеки в [purchases].
  Future<void> restore() async {
    if (!isSupported) return;
    await _iap.restorePurchases();
  }

  /// Подтвердить стору, что товар выдан. Только после записи права на бэкенде.
  Future<void> complete(StorePurchaseEvent event) async {
    if (!isSupported) return;
    final details = event._details;
    if (details == null || !details.pendingCompletePurchase) return;
    await _iap.completePurchase(details);
  }

  StorePurchaseEvent _toEvent(PurchaseDetails details) {
    // iOS: идентификатор транзакции — то, о чём можно спросить App Store
    // Server API. Android: serverVerificationData и есть purchase token.
    // Порядок именно такой: на iOS serverVerificationData у StoreKit 1 — это
    // чек всего приложения, по которому бэкенд ничего не найдёт.
    final receipt = defaultTargetPlatform == TargetPlatform.iOS
        ? (details.purchaseID ?? details.verificationData.serverVerificationData)
        : details.verificationData.serverVerificationData;
    return StorePurchaseEvent(
      productId: details.productID,
      receipt: receipt,
      outcome: switch (details.status) {
        PurchaseStatus.purchased => StorePurchaseOutcome.purchased,
        PurchaseStatus.restored => StorePurchaseOutcome.restored,
        PurchaseStatus.pending => StorePurchaseOutcome.pending,
        PurchaseStatus.canceled => StorePurchaseOutcome.canceled,
        PurchaseStatus.error => StorePurchaseOutcome.failed,
      },
      errorMessage: details.error?.message,
      details: details,
    );
  }
}
