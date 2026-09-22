import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// `extensions.code`, с которым бэкенд отказывает в чеке окончательно: чек
/// привязан к другому живому аккаунту, возвращён или называет неизвестный
/// товар. Повторная попытка ничего не изменит — транзакцию стору надо
/// завершить, иначе StoreKit будет перевыдавать её при каждом запуске.
const purchaseRejectedCode = 'purchase_rejected';

/// `extensions.code` окончательного отказа «чек привязан к другому живому
/// аккаунту». Транзакцию завершаем так же, как при [purchaseRejectedCode], но
/// витрина ещё и перестаёт продавать: аккаунт стора уже платит за подписку,
/// и второй пропуск был бы вторым списанием.
const purchaseOwnedElsewhereCode = 'purchase_owned_elsewhere';

/// Код ошибки плагина на iOS: у StoreKit уже лежит незавершённая транзакция
/// этого товара, и новую покупку он не начнёт. Лечится восстановлением
/// покупок — очередь перевыдаст транзакцию, и она либо пройдёт, либо будет
/// завершена по окончательному отказу.
const storeKitDuplicateProductCode = 'storekit_duplicate_product_object';

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
    on<LavaPurchaseRequested>(_onLavaPurchaseRequested);
    on<LavaReturnRequested>(_onLavaReturnRequested);
    on<LavaCancelRequested>(_onLavaCancelRequested);
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

  /// Пауза между опросами счёта lava.top на странице возврата. Тесты ставят
  /// ноль.
  @visibleForTesting
  static Duration lavaPollInterval = const Duration(seconds: 2);

  /// Сколько раз страница возврата переспрашивает бэкенд, прежде чем сдаться
  /// (вебхук lava.top обычно приходит за секунды, а бэкенд и сам
  /// переспрашивает lava.top на каждом опросе).
  @visibleForTesting
  static int lavaPollAttempts = 45;

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
      await _loadPersonal(emit);
      // Сверка со стором объявляется тем же состоянием, что открывает экран:
      // ни одного кадра с отпертыми кнопками до её конца.
      emit(state.copyWith(inProgress: false, syncingStore: _storeSyncNeeded));
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
      return;
    }
    // Экран уже показан; прежде чем разрешить покупку, сверяемся со стором.
    if (state.syncingStore) await _syncStorePurchases(emit);
  }

  /// Сверяться со стором есть смысл, только когда есть что продавать: стор на
  /// месте, а подписки у аккаунта нет.
  bool get _storeSyncNeeded =>
      _store.platform != null &&
      state.storeAvailable &&
      !state.subscription.active;

  /// Подписка, покупки и история — то, что есть только у авторизованного.
  Future<void> _loadPersonal(Emitter<SubscriptionState> emit) async {
    final subscription = await _repository.mySubscription();
    final purchases = await _repository.myPurchases();
    final periods = await _repository.myPeriods();
    emit(
      state.copyWith(
        subscription: subscription,
        purchases: purchases,
        periods: periods,
      ),
    );
  }

  /// Не продать второй пропуск тому, за кого стор уже списывает деньги.
  ///
  /// У аккаунта стора может быть живая подписка, о которой бэкенд не знает:
  /// оформленная с другого аккаунта приложения — чаще всего удалённого, ведь
  /// удаление аккаунта подписку в App Store не отменяет. Пока подписки у
  /// этого аккаунта нет, витрина тихо спрашивает у стора действующие покупки
  /// и несёт их на бэкенд, как при «восстановить покупки». Дальше три исхода:
  /// подписка удалённого аккаунта переезжает сюда — и кнопки запираются как
  /// при действующей подписке; чек принадлежит другому живому аккаунту —
  /// кнопки заперты с объяснением; стор ничего не знает — продаём.
  ///
  /// Сетевые и серверные ошибки здесь молчат: человек ничего не нажимал, а
  /// транзакцию стор перевыдаст сам.
  Future<void> _syncStorePurchases(Emitter<SubscriptionState> emit) async {
    try {
      final existing = await _store.currentPurchases();
      var elsewhere = false;
      var claimed = false;
      for (final purchase in existing) {
        switch (await _redeem(purchase, emit, silent: true)) {
          case _RedeemOutcome.granted:
            claimed = true;
          case _RedeemOutcome.ownedElsewhere:
            elsewhere = true;
          case _RedeemOutcome.rejected:
          case _RedeemOutcome.retryLater:
            break;
        }
      }
      if (elsewhere) {
        analytics.logCheckoutStep(step: 'store_subscription_elsewhere');
      }
      if (claimed) {
        analytics.logCheckoutStep(step: 'store_purchase_claimed');
        await _loadPersonal(emit);
        emit(
          state.copyWith(
            infoMessage: LocaleKeys.subscription_restoreFound.tr(),
          ),
        );
      }
      emit(state.copyWith(storeSubscriptionElsewhere: elsewhere));
    } catch (e) {
      debugPrint('store: sync of current purchases failed: $e');
    } finally {
      emit(state.copyWith(syncingStore: false));
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
      await _store.buy(productId: productId);
    } catch (e) {
      if (e is PlatformException && e.code == storeKitDuplicateProductCode) {
        // Не «магазин недоступен»: в очереди StoreKit застряла транзакция
        // этого же товара. Перевыдаём её через restore — как правило, это
        // покупка, которую бэкенд однажды не принял.
        emit(
          state.copyWith(
            purchasingSku: null,
            infoMessage: LocaleKeys.subscription_purchaseAlreadyInStore.tr(),
          ),
        );
        analytics.logCheckoutStep(
          step: 'purchase_stuck_in_queue',
          sku: event.sku,
        );
        add(PurchasesRestoreRequested());
        return;
      }
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

    // Кнопка продолжает показывать «обрабатываем платёж», пока право не
    // записано: окно стора уже закрылось, и без этого экран выглядел бы так,
    // будто ничего не происходит. Чек без нажатия привязываем к тарифу по
    // товару.
    final sku = state.purchasingSku ?? _skuOf(purchase.productId, platform);
    emit(state.copyWith(redeeming: true, purchasingSku: sku));
    final outcome = await _redeem(purchase, emit, silent: false);
    if (outcome != _RedeemOutcome.granted) {
      emit(
        state.copyWith(
          redeeming: false,
          purchasingSku: null,
          // Чужой живой аккаунт — это ещё и запрет продавать дальше.
          storeSubscriptionElsewhere:
              outcome == _RedeemOutcome.ownedElsewhere ||
              state.storeSubscriptionElsewhere,
        ),
      );
      return;
    }
    final restored = purchase.outcome == StorePurchaseOutcome.restored;
    emit(
      state.copyWith(
        redeeming: false,
        purchasingSku: null,
        // Восстановление тем и отличается от покупки, что ничего нового не
        // произошло — говорить «спасибо за покупку» было бы странно.
        infoMessage: restored
            ? LocaleKeys.subscription_restoreFound.tr()
            : LocaleKeys.subscription_purchaseActivated.tr(),
        activatedSku: restored ? null : (sku ?? purchase.productId),
      ),
    );
    add(SubscriptionRequested());
  }

  /// Отнести чек на бэкенд и, если право записано, открыть фичи и завершить
  /// транзакцию стору. Ошибку в состояние кладёт только не-[silent] вызов —
  /// тихой сверке со стором ([_syncStorePurchases]) показывать нечего.
  Future<_RedeemOutcome> _redeem(
    StorePurchaseEvent purchase,
    Emitter<SubscriptionState> emit, {
    required bool silent,
  }) async {
    final platform = _store.platform;
    if (platform == null) return _RedeemOutcome.retryLater;
    final SubscriptionStatus status;
    try {
      status = await _repository.redeemPurchase(
        platform: platform,
        productId: purchase.productId,
        receipt: purchase.receipt,
      );
    } on GraphqlException catch (e) {
      if (!silent) {
        emit(state.copyWith(errorMessage: describeActionError(e)));
      }
      final ownedElsewhere = e.code == purchaseOwnedElsewhereCode;
      if (ownedElsewhere || e.code == purchaseRejectedCode) {
        // Окончательный отказ (чужой живой аккаунт, возврат, неизвестный
        // товар): держать транзакцию в очереди бессмысленно — она бы
        // всплывала с той же ошибкой при каждом запуске и блокировала новую
        // покупку того же товара. Право стор и так не выдал.
        analytics.logCheckoutStep(step: 'purchase_rejected');
        await _store.complete(purchase);
        return ownedElsewhere
            ? _RedeemOutcome.ownedElsewhere
            : _RedeemOutcome.rejected;
      }
      // Сетевая или серверная ошибка: чек стору не подтверждаем, пусть
      // покупка останется незакрытой и приложение попробует ещё раз при
      // следующем запуске.
      return _RedeemOutcome.retryLater;
    }
    await _repository.refreshGrants();
    await _store.complete(purchase);
    analytics.logCheckoutStep(step: 'purchase_completed');
    emit(state.copyWith(subscription: status));
    return _RedeemOutcome.granted;
  }

  /// SKU тарифа, чей товар в [platform] — [productId]; `null`, если каталог
  /// такого товара не знает.
  String? _skuOf(String productId, StorePlatform platform) {
    for (final tariff in state.tariffs) {
      if (tariff.productIdFor(platform) == productId) return tariff.sku;
    }
    return null;
  }

  // ------------------------------------------------ lava.top (веб, рубли)

  /// Куда lava.top вернёт человека после оплаты: та же страница сайта, с
  /// которого он ушёл (dev возвращается на dev). Вне браузера адреса нет —
  /// бэкенд подставит боевой сайт.
  static String? lavaReturnUrl() {
    if (!kIsWeb) return null;
    final base = Uri.base;
    if (!base.hasScheme || !base.scheme.startsWith('http')) return null;
    return '${base.origin}/tariffs/lava';
  }

  /// Оплата рублями: счёт на бэкенде → страница оплаты lava.top. Дальше
  /// человек возвращается на `/tariffs/lava`, и активацию ждёт уже она.
  Future<void> _onLavaPurchaseRequested(
    LavaPurchaseRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (state.busy) return;
    emit(
      state.copyWith(
        purchasingSku: event.sku,
        errorMessage: null,
        infoMessage: null,
      ),
    );
    analytics.logCheckoutStep(step: 'lava_started', sku: event.sku);
    try {
      final invoice = await _repository.createLavaInvoice(
        sku: event.sku,
        returnUrl: lavaReturnUrl() ?? '',
      );
      final url = invoice.paymentUrl;
      if (url == null || url.isEmpty) {
        throw GraphqlException(LocaleKeys.subscription_lavaFailed.tr());
      }
      analytics.logCheckoutStep(step: 'lava_redirected', sku: event.sku);
      await _store.openPaymentPage(Uri.parse(url));
      // Кнопка остаётся запертой: вкладка сейчас уйдёт на lava.top.
    } on GraphqlException catch (e) {
      final message = e.code == lavaSubscriptionActiveCode
          ? LocaleKeys.subscription_lavaBlockedUntil.tr(
              args: [_blockedUntilLabel()],
            )
          : describeActionError(e);
      emit(state.copyWith(purchasingSku: null, errorMessage: message));
      analytics.logCheckoutStep(step: 'lava_failed', sku: event.sku);
    } catch (e) {
      debugPrint('lava: failed to start the payment: $e');
      emit(
        state.copyWith(
          purchasingSku: null,
          errorMessage: LocaleKeys.subscription_lavaFailed.tr(),
        ),
      );
      analytics.logCheckoutStep(step: 'lava_failed', sku: event.sku);
    }
  }

  String _blockedUntilLabel() {
    final until =
        state.subscription.purchaseBlockedUntil ?? state.subscription.endsAt;
    return until == null ? '' : DateFormat.yMMMd().format(until);
  }

  /// Страница возврата: опрашиваем счёт, пока он не оплачен, потом открываем
  /// фичи и уходим на экран подписки тем же сигналом, что и покупка в сторе.
  Future<void> _onLavaReturnRequested(
    LavaReturnRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(
      state.copyWith(
        lavaAwaitingPayment: true,
        lavaPaymentFailed: false,
        errorMessage: null,
      ),
    );
    LavaInvoice? invoice;
    for (var attempt = 0; attempt < lavaPollAttempts; attempt++) {
      if (isClosed) return;
      try {
        invoice = await _repository.lavaInvoice(event.invoiceId);
      } on GraphqlException catch (e) {
        if (e.isAuthError) {
          // Сессии нет: страница показывает вход, после него опрос повторят.
          emit(
            state.copyWith(
              lavaAwaitingPayment: false,
              errorMessage: describeActionError(e),
            ),
          );
          return;
        }
        debugPrint('lava: poll failed: $e');
      } catch (e) {
        debugPrint('lava: poll failed: $e');
      }
      if (invoice != null && invoice.status != LavaInvoiceStatus.pending) {
        break;
      }
      await Future<void>.delayed(lavaPollInterval);
    }
    if (invoice?.status == LavaInvoiceStatus.paid) {
      final sku = invoice!.sku;
      analytics.logCheckoutStep(step: 'lava_paid', sku: sku);
      try {
        await _repository.refreshGrants();
        await _loadPersonal(emit);
      } catch (e) {
        debugPrint('lava: failed to reload after the payment: $e');
      }
      emit(
        state.copyWith(
          lavaAwaitingPayment: false,
          infoMessage: LocaleKeys.subscription_purchaseActivated.tr(),
          activatedSku: sku,
        ),
      );
      return;
    }
    analytics.logCheckoutStep(step: 'lava_failed', sku: invoice?.sku);
    emit(
      state.copyWith(
        lavaAwaitingPayment: false,
        lavaPaymentFailed: true,
        errorMessage: invoice?.status == LavaInvoiceStatus.failed
            ? LocaleKeys.subscription_lavaFailed.tr()
            : LocaleKeys.subscription_lavaTimeout.tr(),
      ),
    );
  }

  /// Отмена подписки lava.top: доступ до конца оплаченного периода, списаний
  /// больше нет. Новое состояние приходит с ответом.
  Future<void> _onLavaCancelRequested(
    LavaCancelRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (state.lavaCancelling) return;
    emit(state.copyWith(lavaCancelling: true, errorMessage: null));
    try {
      final status = await _repository.cancelLavaSubscription();
      final purchases = await _repository.myPurchases();
      final endsAt = status.lavaSubscription?.endsAt ?? status.endsAt;
      emit(
        state.copyWith(
          lavaCancelling: false,
          subscription: status,
          purchases: purchases,
          infoMessage: endsAt == null
              ? null
              : LocaleKeys.subscription_lavaCancelled.tr(
                  args: [DateFormat.yMMMd().format(endsAt)],
                ),
        ),
      );
      analytics.logCheckoutStep(
        step: 'lava_cancelled',
        sku: status.lavaSubscription?.sku,
      );
    } catch (e) {
      emit(
        state.copyWith(
          lavaCancelling: false,
          errorMessage: describeActionError(e),
        ),
      );
    }
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

/// Чем кончился поход с чеком на бэкенд.
enum _RedeemOutcome {
  /// Право записано, транзакция завершена.
  granted,

  /// Чек принадлежит другому живому аккаунту: транзакция завершена, продавать
  /// этому аккаунту стора больше нельзя.
  ownedElsewhere,

  /// Другой окончательный отказ (возврат, неизвестный товар): транзакция
  /// завершена.
  rejected,

  /// Сеть или сервер: транзакция остаётся в очереди стора.
  retryLater,
}
