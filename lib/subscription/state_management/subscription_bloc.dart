import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/error_messages.dart';
import '../../generated/locale_keys.g.dart';
import '../data/store_purchase_service.dart';
import '../data/subscription_repository.dart';
import '../models/subscription_models.dart';
import 'subscription_events.dart';
import 'subscription_state.dart';

/// Bloc витрины тарифов и раздела «Подписка».
///
/// Каталог тарифов публичный, всё остальное требует сессии — у гостя экран
/// показывает только цены и предложение войти.
///
/// Покупка идёт через стор, и её результат приходит **не из вызова
/// [StorePurchaseService.buy]**, а из очереди покупок: стор присылает чек и
/// тогда, когда человек оплатил на другом устройстве, и когда отложенный
/// платёж наконец прошёл. Поэтому Bloc всё время слушает очередь, а `buy`
/// только открывает окно оплаты.
@injectable
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc(this._repository, this._store)
    : super(const SubscriptionState()) {
    on<SubscriptionRequested>(_onRequested);
    on<PurchaseRequested>(_onPurchaseRequested);
    on<PurchasesRestoreRequested>(_onRestoreRequested);
    on<StorePurchaseReceived>(_onStorePurchase);
    on<RemindersToggled>(_onRemindersToggled);
    _storeSubscription = _store.purchases.listen(
      (event) => add(StorePurchaseReceived(event)),
    );
    add(SubscriptionRequested());
  }

  final SubscriptionRepository _repository;
  final StorePurchaseService _store;
  StreamSubscription<StorePurchaseEvent>? _storeSubscription;

  /// Стор этой сборки; `null` в вебе.
  StorePlatform? get storePlatform => _store.platform;

  @override
  Future<void> close() {
    _storeSubscription?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    SubscriptionRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      final tariffs = await _repository.tariffs();
      emit(state.copyWith(tariffs: tariffs));
      await _loadStorePrices(tariffs, emit);
      // Личные данные — только для авторизованного; гостю витрины достаточно.
      final subscription = await _repository.mySubscription();
      final purchases = await _repository.myPurchases();
      final periods = await _repository.myPeriods();
      emit(
        state.copyWith(
          inProgress: false,
          subscription: subscription,
          purchases: purchases,
          periods: periods,
        ),
      );
    } on GraphqlException catch (e) {
      // Гость: тарифы уже загружены, отсутствие сессии — не ошибка экрана.
      if (e.isAuthError) {
        emit(state.copyWith(inProgress: false));
        return;
      }
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          inProgress: false,
          errorMessage: LocaleKeys.subscription_loadFailed.tr(),
        ),
      );
    }
  }

  /// Спросить у стора цены заведённых товаров. Молча ничего не делает там, где
  /// стора нет, — витрина тогда живёт на справочных ценах.
  Future<void> _loadStorePrices(
    List<Tariff> tariffs,
    Emitter<SubscriptionState> emit,
  ) async {
    final platform = _store.platform;
    if (platform == null) return;
    if (!await _store.isAvailable()) return;
    final ids = <String>{
      for (final tariff in tariffs)
        if (tariff.productIdFor(platform).isNotEmpty)
          tariff.productIdFor(platform),
    };
    try {
      final products = await _store.products(ids);
      emit(
        state.copyWith(
          storeProducts: {for (final p in products) p.id: p},
          // Покупать можно, только если стор действительно знает товары:
          // иначе кнопка открывала бы пустое окно оплаты.
          storeAvailable: products.isNotEmpty,
        ),
      );
    } catch (_) {
      // Цены — украшение витрины; без них она работает на справочных.
    }
  }

  Future<void> _onPurchaseRequested(
    PurchaseRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final platform = _store.platform;
    if (platform == null || state.busy) return;
    Tariff? tariff;
    for (final t in state.tariffs) {
      if (t.sku == event.sku) tariff = t;
    }
    final productId = tariff?.productIdFor(platform) ?? '';
    if (tariff == null || productId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: LocaleKeys.subscription_storeUnavailable.tr(),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        purchasingSku: event.sku,
        errorMessage: null,
        infoMessage: null,
      ),
    );
    analytics.logCheckoutStep(step: 'purchase_started', sku: event.sku);
    try {
      await _store.buy(productId: productId, autoRenewing: tariff.autoRenewing);
    } catch (e) {
      emit(
        state.copyWith(
          purchasingSku: null,
          errorMessage: LocaleKeys.subscription_storeUnavailable.tr(),
        ),
      );
      analytics.logCheckoutStep(step: 'purchase_failed', sku: event.sku);
    }
  }

  Future<void> _onRestoreRequested(
    PurchasesRestoreRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (state.restoring) return;
    emit(
      state.copyWith(restoring: true, errorMessage: null, infoMessage: null),
    );
    analytics.logCheckoutStep(step: 'purchases_restored');
    try {
      await _store.restore();
    } catch (_) {
      // Ошибку стора показываем как «нечего восстанавливать»: другого исхода
      // человек отсюда всё равно не добьётся.
    }
    // Чеки (если они есть) придут в очередь покупок и обработаются как обычно;
    // отдельного ответа у restore нет.
    emit(
      state.copyWith(
        restoring: false,
        infoMessage: LocaleKeys.subscription_restoreDone.tr(),
      ),
    );
  }

  /// Чек из стора: несём на бэкенд, открываем фичи и только потом подтверждаем
  /// покупку стору — неподтверждённую Google вернёт покупателю через трое
  /// суток, и это правильный исход, если право записать не удалось.
  Future<void> _onStorePurchase(
    StorePurchaseReceived event,
    Emitter<SubscriptionState> emit,
  ) async {
    final purchase = event.event;
    final platform = _store.platform;
    switch (purchase.outcome) {
      case StorePurchaseOutcome.canceled:
        analytics.logCheckoutStep(step: 'purchase_cancelled');
        emit(state.copyWith(purchasingSku: null));
        await _store.complete(purchase);
        return;
      case StorePurchaseOutcome.failed:
        analytics.logCheckoutStep(step: 'purchase_failed');
        emit(
          state.copyWith(
            purchasingSku: null,
            errorMessage:
                purchase.errorMessage ??
                LocaleKeys.subscription_purchaseFailed.tr(),
          ),
        );
        await _store.complete(purchase);
        return;
      case StorePurchaseOutcome.pending:
        emit(
          state.copyWith(
            purchasingSku: null,
            infoMessage: LocaleKeys.subscription_purchasePending.tr(),
          ),
        );
        return;
      case StorePurchaseOutcome.purchased:
      case StorePurchaseOutcome.restored:
        break;
    }
    if (platform == null) return;

    emit(state.copyWith(redeeming: true, purchasingSku: null));
    final SubscriptionStatus status;
    try {
      status = await _repository.redeemPurchase(
        platform: platform,
        productId: purchase.productId,
        receipt: purchase.receipt,
      );
    } on GraphqlException catch (e) {
      // Чек стору не подтверждаем: пусть покупка останется незакрытой и
      // приложение попробует ещё раз при следующем запуске.
      emit(
        state.copyWith(redeeming: false, errorMessage: describeActionError(e)),
      );
      return;
    }
    await _repository.refreshGrants();
    await _store.complete(purchase);
    analytics.logCheckoutStep(step: 'purchase_completed');
    emit(
      state.copyWith(
        redeeming: false,
        subscription: status,
        // Восстановление тем и отличается от покупки, что ничего нового не
        // произошло — говорить «спасибо за покупку» было бы странно.
        infoMessage: purchase.outcome == StorePurchaseOutcome.restored
            ? LocaleKeys.subscription_restoreFound.tr()
            : LocaleKeys.subscription_purchaseActivated.tr(),
      ),
    );
    add(SubscriptionRequested());
  }

  Future<void> _onRemindersToggled(
    RemindersToggled event,
    Emitter<SubscriptionState> emit,
  ) async {
    final SubscriptionStatus status;
    try {
      status = await _repository.setReminders(event.enabled);
    } on GraphqlException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return;
    }
    emit(state.copyWith(subscription: status));
  }
}
