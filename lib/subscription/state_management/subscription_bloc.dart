import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
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
  SubscriptionBloc(this._repository) : super(const SubscriptionState()) {
    on<SubscriptionRequested>(_onRequested);
    on<OrderRequested>(_onOrderRequested);
    on<OrderCancelled>(_onOrderCancelled);
    on<RemindersToggled>(_onRemindersToggled);
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
    emit(state.copyWith(submitting: true, errorMessage: null));
    try {
      final order = await _repository.createOrder(event.sku);
      emit(
        state.copyWith(
          submitting: false,
          orders: [order, ...state.orders.where((o) => o.id != order.id)],
        ),
      );
    } on GraphqlException catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: e.message));
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
