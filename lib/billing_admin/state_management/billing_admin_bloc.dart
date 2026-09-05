import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../generated/locale_keys.g.dart';
import '../data/billing_admin_repository.dart';
import '../models/billing_admin_models.dart';
import 'billing_admin_events.dart';
import 'billing_admin_state.dart';

/// Денежный стол: покупки в сторах, карточка пользователя с ручными выдачами,
/// журнал и каталог тарифов. Экран доступен держателям `manage_billing`; само
/// право проверяет бэкенд на каждом запросе.
///
/// Подтверждать оплату оператору больше нечего — сторы берут деньги сами, и
/// право появляется по проверенному чеку. Ручная выдача осталась: ею чинят
/// возвраты, компенсации и апгрейд «базовый → с русским».
@injectable
class BillingAdminBloc extends Bloc<BillingAdminEvent, BillingAdminState> {
  BillingAdminBloc(this._repository) : super(const BillingAdminState()) {
    on<BillingAdminStarted>(_onStarted);
    on<BillingTabSelected>(_onTabSelected);
    on<PurchasesFilterChanged>(_onPurchasesFilterChanged);
    on<SearchDraftChanged>(
      (e, emit) => emit(state.copyWith(searchDraft: e.text)),
    );
    on<PurchasesPageRequested>(_onPurchasesPageRequested);
    on<PurchasesRefreshed>(_onPurchasesRefreshed);
    on<UserLookedUp>(_onUserLookedUp);
    on<UserEmailDraftChanged>(
      (e, emit) => emit(state.copyWith(userEmailDraft: e.text)),
    );
    on<GrantFormChanged>(
      (e, emit) => emit(
        state.copyWith(
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
  }

  final BillingAdminRepository _repository;

  // ------------------------------------------------------------- загрузка

  Future<void> _onStarted(
    BillingAdminStarted event,
    Emitter<BillingAdminState> emit,
  ) async {
    await _loadPurchases(emit, offset: 0);
  }

  Future<void> _onTabSelected(
    BillingTabSelected event,
    Emitter<BillingAdminState> emit,
  ) async {
    emit(_clean().copyWith(tab: event.tab));
    switch (event.tab) {
      case BillingTab.purchases:
      case BillingTab.user:
        break;
      case BillingTab.audit:
        if (!state.auditLoaded) await _loadAudit(emit);
      case BillingTab.tariffs:
        if (!state.tariffsLoaded) await _loadTariffs(emit);
    }
  }

  Future<void> _loadPurchases(
    Emitter<BillingAdminState> emit, {
    required int offset,
  }) async {
    emit(state.copyWith(purchasesLoading: true, errorMessage: null));
    try {
      final page = await _repository.purchases(
        platform: state.platformFilter,
        search: state.search,
        limit: state.purchasesPageSize,
        offset: offset,
      );
      emit(
        state.copyWith(
          purchasesLoading: false,
          purchases: page.items,
          purchasesTotal: page.total,
          purchasesOffset: offset,
        ),
      );
    } catch (e) {
      emit(state.copyWith(purchasesLoading: false, errorMessage: _message(e)));
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

  // -------------------------------------------------------------- покупки

  Future<void> _onPurchasesFilterChanged(
    PurchasesFilterChanged event,
    Emitter<BillingAdminState> emit,
  ) async {
    final search = event.search ?? state.searchDraft;
    emit(
      _clean().copyWith(
        platformFilter: event.clearPlatform
            ? null
            : (event.platform ?? state.platformFilter),
        search: search,
        searchDraft: search,
      ),
    );
    await _loadPurchases(emit, offset: 0);
  }

  Future<void> _onPurchasesPageRequested(
    PurchasesPageRequested event,
    Emitter<BillingAdminState> emit,
  ) => _loadPurchases(emit, offset: event.offset < 0 ? 0 : event.offset);

  Future<void> _onPurchasesRefreshed(
    PurchasesRefreshed event,
    Emitter<BillingAdminState> emit,
  ) => _loadPurchases(emit, offset: state.purchasesOffset);

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
