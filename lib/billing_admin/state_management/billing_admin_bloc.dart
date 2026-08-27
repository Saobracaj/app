import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../generated/locale_keys.g.dart';
import '../data/billing_admin_repository.dart';
import '../models/billing_admin_models.dart';
import 'billing_admin_events.dart';
import 'billing_admin_state.dart';

/// Денежный стол: заказы с подтверждением оплаты, карточка пользователя с
/// ручными выдачами, журнал, тарифы и реквизиты получателя. Экран доступен
/// держателям `manage_billing`; само право проверяет бэкенд на каждом запросе.
@injectable
class BillingAdminBloc extends Bloc<BillingAdminEvent, BillingAdminState> {
  BillingAdminBloc(this._repository) : super(const BillingAdminState()) {
    on<BillingAdminStarted>(_onStarted);
    on<BillingTabSelected>(_onTabSelected);
    on<OrdersFilterChanged>(_onOrdersFilterChanged);
    on<SearchDraftChanged>(
      (e, emit) => emit(state.copyWith(searchDraft: e.text)),
    );
    on<OrdersPageRequested>(_onOrdersPageRequested);
    on<OrdersRefreshed>(_onOrdersRefreshed);
    on<OrderConfirmed>(_onOrderConfirmed);
    on<OrderCancelledByAdmin>(_onOrderCancelled);
    on<UserLookedUp>(_onUserLookedUp);
    on<UserEmailDraftChanged>(
      (e, emit) => emit(state.copyWith(userEmailDraft: e.text)),
    );
    on<GrantFormChanged>(
      (e, emit) => emit(
        state.copyWith(
          grantKind: e.kind ?? state.grantKind,
          grantMonths: e.months ?? state.grantMonths,
          grantNote: e.note ?? state.grantNote,
        ),
      ),
    );
    on<UserRefreshed>(_onUserRefreshed);
    on<SubscriptionGranted>(_onGranted);
    on<SubscriptionExtended>(_onExtended);
    on<SubscriptionRevoked>(_onRevoked);
    on<AuditRefreshed>(_onAuditRefreshed);
    on<TariffPriceDraftChanged>(
      (e, emit) => emit(
        state.copyWith(priceDrafts: {...state.priceDrafts, e.sku: e.text}),
      ),
    );
    on<TariffPriceCommitted>(_onTariffPriceCommitted);
    on<TariffActiveToggled>(_onTariffActiveToggled);
    on<PromosRefreshed>((e, emit) => _loadPromos(emit));
    on<PromoFormChanged>(
      (e, emit) => emit(
        state.copyWith(
          promoCount: e.count ?? state.promoCount,
          promoDiscount: e.discount ?? state.promoDiscount,
          promoValidUntil: e.validUntil ?? state.promoValidUntil,
          promoSku: e.clearSku ? null : (e.sku ?? state.promoSku),
          promoNote: e.note ?? state.promoNote,
        ),
      ),
    );
    on<PromoCodesGenerated>(_onPromoCodesGenerated);
    on<PromoCodeDeleted>(_onPromoCodeDeleted);
    on<PayeeDraftChanged>(
      (e, emit) => emit(
        state.copyWith(
          payeeDraft: state.payeeDraft.copyWith(
            accountNumber: e.accountNumber ?? state.payeeDraft.accountNumber,
            name: e.name ?? state.payeeDraft.name,
            address: e.address ?? state.payeeDraft.address,
            paymentCode: e.paymentCode ?? state.payeeDraft.paymentCode,
            purpose: e.purpose ?? state.payeeDraft.purpose,
          ),
        ),
      ),
    );
    on<PayeeSaved>(_onPayeeSaved);
  }

  final BillingAdminRepository _repository;

  // ------------------------------------------------------------- загрузка

  Future<void> _onStarted(
    BillingAdminStarted event,
    Emitter<BillingAdminState> emit,
  ) async {
    await _loadPayee(emit);
    await _loadOrders(emit, offset: 0);
  }

  Future<void> _onTabSelected(
    BillingTabSelected event,
    Emitter<BillingAdminState> emit,
  ) async {
    emit(_clean().copyWith(tab: event.tab));
    switch (event.tab) {
      case BillingTab.orders:
      case BillingTab.user:
        break;
      case BillingTab.audit:
        if (!state.auditLoaded) await _loadAudit(emit);
      case BillingTab.tariffs:
        if (!state.tariffsLoaded) await _loadTariffs(emit);
      case BillingTab.promos:
        // Тарифы нужны выпадашке «привязать к тарифу» в форме генерации.
        if (!state.tariffsLoaded) await _loadTariffs(emit);
        if (!state.promosLoaded) await _loadPromos(emit);
      case BillingTab.payee:
        if (state.payee == null) await _loadPayee(emit);
    }
  }

  Future<void> _loadOrders(
    Emitter<BillingAdminState> emit, {
    required int offset,
  }) async {
    emit(state.copyWith(ordersLoading: true, errorMessage: null));
    try {
      final page = await _repository.orders(
        status: state.statusFilter,
        search: state.search,
        limit: state.ordersPageSize,
        offset: offset,
      );
      emit(
        state.copyWith(
          ordersLoading: false,
          orders: page.items,
          ordersTotal: page.total,
          ordersOffset: offset,
        ),
      );
    } catch (e) {
      emit(state.copyWith(ordersLoading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _loadPayee(Emitter<BillingAdminState> emit) async {
    emit(state.copyWith(payeeLoading: true));
    try {
      final payee = await _repository.payee();
      emit(
        state.copyWith(
          payeeLoading: false,
          payee: payee,
          payeeDraft: PayeeDraft.fromPayee(payee),
        ),
      );
    } catch (e) {
      emit(state.copyWith(payeeLoading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _loadAudit(Emitter<BillingAdminState> emit) async {
    emit(state.copyWith(auditLoading: true, errorMessage: null));
    try {
      final audit = await _repository.auditLog();
      emit(
        state.copyWith(auditLoading: false, auditLoaded: true, audit: audit),
      );
    } catch (e) {
      emit(state.copyWith(auditLoading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _loadTariffs(Emitter<BillingAdminState> emit) async {
    emit(state.copyWith(tariffsLoading: true, errorMessage: null));
    try {
      final tariffs = await _repository.allTariffs();
      emit(
        state.copyWith(
          tariffsLoading: false,
          tariffsLoaded: true,
          tariffs: tariffs,
        ),
      );
    } catch (e) {
      emit(state.copyWith(tariffsLoading: false, errorMessage: _message(e)));
    }
  }

  // --------------------------------------------------------------- заказы

  Future<void> _onOrdersFilterChanged(
    OrdersFilterChanged event,
    Emitter<BillingAdminState> emit,
  ) async {
    final search = event.search ?? state.searchDraft;
    emit(
      _clean().copyWith(
        statusFilter: event.clearStatus
            ? null
            : (event.status ?? state.statusFilter),
        search: search,
        searchDraft: search,
      ),
    );
    await _loadOrders(emit, offset: 0);
  }

  Future<void> _onOrdersPageRequested(
    OrdersPageRequested event,
    Emitter<BillingAdminState> emit,
  ) => _loadOrders(emit, offset: event.offset < 0 ? 0 : event.offset);

  Future<void> _onOrdersRefreshed(
    OrdersRefreshed event,
    Emitter<BillingAdminState> emit,
  ) => _loadOrders(emit, offset: state.ordersOffset);

  Future<void> _onOrderConfirmed(
    OrderConfirmed event,
    Emitter<BillingAdminState> emit,
  ) async {
    await _mutate(
      emit,
      () => _repository.confirmOrder(event.orderId),
      info: LocaleKeys.billingAdmin_orderConfirmed.tr(),
    );
    await _afterOrderChange(emit);
  }

  Future<void> _onOrderCancelled(
    OrderCancelledByAdmin event,
    Emitter<BillingAdminState> emit,
  ) async {
    await _mutate(
      emit,
      () => _repository.cancelOrder(event.orderId, reason: event.reason),
      info: LocaleKeys.billingAdmin_orderCancelled.tr(),
    );
    await _afterOrderChange(emit);
  }

  /// Заказ мог поменяться и в списке, и в открытой карточке пользователя —
  /// перечитываем оба, чтобы не показывать «ожидает оплату» после подтверждения.
  Future<void> _afterOrderChange(Emitter<BillingAdminState> emit) async {
    await _loadOrders(emit, offset: state.ordersOffset);
    if (state.user != null) await _reloadUser(emit);
    // Журнал устарел — перечитается при следующем заходе на вкладку.
    emit(state.copyWith(auditLoaded: false));
  }

  // --------------------------------------------------------- пользователь

  Future<void> _onUserLookedUp(
    UserLookedUp event,
    Emitter<BillingAdminState> emit,
  ) async {
    final email = event.email.trim();
    if (email.isEmpty) return;
    emit(
      _clean().copyWith(
        userLoading: true,
        userEmail: email,
        userEmailDraft: email,
        userNotFound: false,
      ),
    );
    await _reloadUser(emit);
  }

  Future<void> _onUserRefreshed(
    UserRefreshed event,
    Emitter<BillingAdminState> emit,
  ) => _reloadUser(emit);

  Future<void> _reloadUser(Emitter<BillingAdminState> emit) async {
    if (state.userEmail.isEmpty) return;
    emit(state.copyWith(userLoading: true));
    try {
      final user = await _repository.user(state.userEmail);
      emit(
        state.copyWith(
          userLoading: false,
          user: user,
          userNotFound: user == null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(userLoading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onGranted(
    SubscriptionGranted event,
    Emitter<BillingAdminState> emit,
  ) async {
    final user = state.user;
    if (user == null) return;
    await _mutate(
      emit,
      () => _repository.grantSubscription(
        userId: user.userId,
        kind: event.kind,
        months: event.months,
        note: event.note,
      ),
      info: LocaleKeys.billingAdmin_granted.tr(),
    );
    await _afterUserChange(emit);
  }

  Future<void> _onExtended(
    SubscriptionExtended event,
    Emitter<BillingAdminState> emit,
  ) async {
    final user = state.user;
    if (user == null) return;
    await _mutate(
      emit,
      () => _repository.extendSubscription(
        userId: user.userId,
        months: event.months,
        note: event.note,
      ),
      info: LocaleKeys.billingAdmin_extended.tr(),
    );
    await _afterUserChange(emit);
  }

  Future<void> _onRevoked(
    SubscriptionRevoked event,
    Emitter<BillingAdminState> emit,
  ) async {
    final user = state.user;
    if (user == null) return;
    await _mutate(
      emit,
      () =>
          _repository.revokeSubscription(userId: user.userId, note: event.note),
      info: LocaleKeys.billingAdmin_revoked.tr(),
    );
    await _afterUserChange(emit);
  }

  Future<void> _afterUserChange(Emitter<BillingAdminState> emit) async {
    await _reloadUser(emit);
    emit(state.copyWith(auditLoaded: false));
  }

  // ---------------------------------------------------------------- журнал

  Future<void> _onAuditRefreshed(
    AuditRefreshed event,
    Emitter<BillingAdminState> emit,
  ) => _loadAudit(emit);

  // ---------------------------------------------------------------- тарифы

  Future<void> _onTariffPriceCommitted(
    TariffPriceCommitted event,
    Emitter<BillingAdminState> emit,
  ) async {
    final draft = state.priceDrafts[event.sku];
    if (draft == null) return;
    AdminTariff? current;
    for (final t in state.tariffs) {
      if (t.sku == event.sku) current = t;
    }
    final price = int.tryParse(draft.trim());
    if (price == null || price <= 0) {
      emit(
        state.copyWith(
          errorMessage: LocaleKeys.billingAdmin_pricePositive.tr(),
        ),
      );
      return;
    }
    // Ушли из поля, ничего не поменяв, — не дёргаем сервер.
    if (current != null && current.priceRsd == price) return;
    await _mutate(
      emit,
      () => _repository.updateTariff(event.sku, priceRsd: price),
      info: LocaleKeys.billingAdmin_tariffSaved.tr(),
    );
    final drafts = {...state.priceDrafts}..remove(event.sku);
    emit(state.copyWith(priceDrafts: drafts));
    await _loadTariffs(emit);
  }

  Future<void> _onTariffActiveToggled(
    TariffActiveToggled event,
    Emitter<BillingAdminState> emit,
  ) async {
    await _mutate(
      emit,
      () => _repository.updateTariff(event.sku, active: event.active),
      info: LocaleKeys.billingAdmin_tariffSaved.tr(),
    );
    await _loadTariffs(emit);
  }

  // ------------------------------------------------------------- промокоды

  Future<void> _loadPromos(Emitter<BillingAdminState> emit) async {
    emit(state.copyWith(promosLoading: true, errorMessage: null));
    try {
      final page = await _repository.promoCodes();
      emit(
        state.copyWith(
          promosLoading: false,
          promosLoaded: true,
          promoCodes: page.items,
        ),
      );
    } catch (e) {
      emit(state.copyWith(promosLoading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onPromoCodesGenerated(
    PromoCodesGenerated event,
    Emitter<BillingAdminState> emit,
  ) async {
    final count = state.promoCountValue;
    final discount = state.promoDiscountValue;
    final validUntil = state.promoValidUntil;
    if (count == null || discount == null || validUntil == null) return;
    emit(_clean().copyWith(submitting: true));
    try {
      final note = state.promoNote.trim();
      final created = await _repository.generatePromoCodes(
        count: count,
        discountPercent: discount,
        // До конца выбранного дня: оператор выбирает дату, а не момент.
        validUntil: DateTime(
          validUntil.year,
          validUntil.month,
          validUntil.day,
          23,
          59,
          59,
        ),
        sku: state.promoSku,
        note: note.isEmpty ? null : note,
      );
      emit(
        state.copyWith(
          submitting: false,
          generatedPromoCodes: created,
          auditLoaded: false,
          infoMessage: LocaleKeys.billingAdmin_promosGenerated.tr(),
        ),
      );
      await _loadPromos(emit);
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onPromoCodeDeleted(
    PromoCodeDeleted event,
    Emitter<BillingAdminState> emit,
  ) async {
    emit(_clean().copyWith(submitting: true));
    try {
      final deleted = await _repository.deletePromoCode(event.code);
      emit(
        state.copyWith(
          submitting: false,
          auditLoaded: !deleted && state.auditLoaded,
          generatedPromoCodes: [
            for (final c in state.generatedPromoCodes)
              if (c.code != event.code) c,
          ],
          infoMessage: deleted
              ? LocaleKeys.billingAdmin_promoDeleted.tr()
              : null,
          errorMessage: deleted
              ? null
              : LocaleKeys.billingAdmin_promoDeleteFailed.tr(),
        ),
      );
      await _loadPromos(emit);
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  // ------------------------------------------------------------ получатель

  Future<void> _onPayeeSaved(
    PayeeSaved event,
    Emitter<BillingAdminState> emit,
  ) async {
    final draft = state.payeeDraft;
    if (!draft.canSave) return;
    emit(_clean().copyWith(submitting: true));
    try {
      final payee = await _repository.updatePayee(
        accountNumber: draft.accountNumber,
        name: draft.name,
        address: draft.address.trim().isEmpty ? null : draft.address,
        paymentCode: draft.paymentCode.trim().isEmpty
            ? null
            : draft.paymentCode,
        purpose: draft.purpose.trim().isEmpty ? null : draft.purpose,
      );
      emit(
        state.copyWith(
          submitting: false,
          payee: payee,
          payeeDraft: PayeeDraft.fromPayee(payee),
          auditLoaded: false,
          infoMessage: LocaleKeys.billingAdmin_payeeSaved.tr(),
        ),
      );
      // Реквизиты появились — у ожидающих заказов теперь есть уплатница.
      await _loadOrders(emit, offset: state.ordersOffset);
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  // --------------------------------------------------------------- helpers

  /// Выполнить мутацию с блокировкой кнопок; ошибка уходит в снэкбар, а
  /// вызывающий всё равно перечитывает данные — так состояние не разъезжается
  /// с сервером даже после неудачи.
  Future<void> _mutate(
    Emitter<BillingAdminState> emit,
    Future<Object?> Function() action, {
    required String info,
  }) async {
    emit(_clean().copyWith(submitting: true));
    try {
      await action();
      emit(state.copyWith(submitting: false, infoMessage: info));
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  /// Состояние без одноразовых сообщений — база для следующего события.
  BillingAdminState _clean() =>
      state.copyWith(errorMessage: null, infoMessage: null);

  String _message(Object e) => e is GraphqlException
      ? e.message
      : LocaleKeys.billingAdmin_requestFailed.tr();
}
