import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../core/network/error_messages.dart';
import '../../feature_flags/data/feature_flags_repository.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';
import '../data/subscription_repository.dart';
import '../models/subscription_models.dart';
import 'subscription_events.dart';
import 'subscription_state.dart';

/// Bloc витрины тарифов и раздела «Подписка».
///
/// Каталог тарифов публичный, всё остальное требует сессии — у гостя экран
/// показывает только цены и предложение войти, а запросы за подпиской и
/// заказами просто не делаются.
@injectable
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  /// Надбавка за русские материалы предвыбрана по тому же локальному флагу,
  /// которым человек уже ответил на вопрос о языке контента при первом запуске
  /// (для русского устройства он включён без вопроса). Берём именно локальный
  /// тумблер, а не `snapshot.russianContent`: последний у непокупателя всегда
  /// выключен — премиум-гранта у него нет, и витрина предлагала бы базовый
  /// тариф русскоязычному человеку.
  SubscriptionBloc(this._repository, FeatureFlagsRepository flags)
    : super(
        SubscriptionState(
          withRussian: flags.snapshot.localEnabled(AppFeature.russianContent),
        ),
      ) {
    on<SubscriptionRequested>(_onRequested);
    on<OrderRequested>(_onOrderRequested);
    on<OrderCancelled>(_onOrderCancelled);
    on<RussianAddonToggled>(_onRussianAddonToggled);
    on<RemindersToggled>(_onRemindersToggled);
    on<PromoCodeDraftChanged>(
      (e, emit) => emit(state.copyWith(promoDraft: e.text, promoError: null)),
    );
    on<PromoCodeApplied>(_onPromoCodeApplied);
    on<PromoCodeCleared>(
      (e, emit) => emit(
        state.copyWith(promo: null, promoDraft: '', promoError: null),
      ),
    );
    add(SubscriptionRequested());
  }

  final SubscriptionRepository _repository;

  Future<void> _onRequested(
    SubscriptionRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      final tariffs = await _repository.tariffs();
      emit(state.copyWith(tariffs: tariffs));
      // Личные данные — только для авторизованного; гостю витрины достаточно.
      final subscription = await _repository.mySubscription();
      final orders = await _repository.myOrders();
      final periods = await _repository.myPeriods();
      emit(
        state.copyWith(
          inProgress: false,
          subscription: subscription,
          orders: orders,
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

  Future<void> _onOrderRequested(
    OrderRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(
      state.copyWith(submitting: true, errorMessage: null, infoMessage: null),
    );
    // Промокод уходит в заказ только если действует на выбранный тариф —
    // иначе бэкенд отказал бы всему заказу из-за нерелевантного кода.
    Tariff? tariff;
    for (final t in state.tariffs) {
      if (t.sku == event.sku) tariff = t;
    }
    final promoCode = tariff == null ? null : state.promoCodeFor(tariff);
    try {
      final order = await _repository.createOrder(
        event.sku,
        promoCode: promoCode,
      );
      // Стопроцентный промокод: заказ уже оплачен, подписка стартовала —
      // открываем фичи и перечитываем состояние, а не ждём оператора.
      if (order.status == OrderStatus.paid) {
        await _repository.refreshGrants();
        emit(
          state.copyWith(
            submitting: false,
            promo: null,
            promoDraft: '',
            orders: [order, ...state.orders.where((o) => o.id != order.id)],
            infoMessage: LocaleKeys.subscription_promoActivated.tr(),
          ),
        );
        add(SubscriptionRequested());
        return;
      }
      emit(
        state.copyWith(
          submitting: false,
          orders: [order, ...state.orders.where((o) => o.id != order.id)],
        ),
      );
    } on GraphqlException catch (e) {
      emit(
        state.copyWith(submitting: false, errorMessage: describeActionError(e)),
      );
    }
  }

  Future<void> _onPromoCodeApplied(
    PromoCodeApplied event,
    Emitter<SubscriptionState> emit,
  ) async {
    final code = state.promoDraft.trim();
    if (code.isEmpty || state.promoChecking) return;
    emit(state.copyWith(promoChecking: true, promoError: null));
    try {
      final promo = await _repository.checkPromoCode(code);
      emit(state.copyWith(promoChecking: false, promo: promo));
    } on GraphqlException catch (e) {
      emit(
        state.copyWith(promoChecking: false, promoError: describeActionError(e)),
      );
    }
  }

  Future<void> _onOrderCancelled(
    OrderCancelled event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(submitting: true, errorMessage: null));
    try {
      final cancelled = await _repository.cancelOrder(event.orderId);
      emit(
        state.copyWith(
          submitting: false,
          orders: [
            for (final order in state.orders)
              if (order.id == cancelled.id) cancelled else order,
          ],
        ),
      );
    } on GraphqlException catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: e.message));
    }
  }

  void _onRussianAddonToggled(
    RussianAddonToggled event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(state.copyWith(withRussian: event.enabled));
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
