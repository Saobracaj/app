import 'package:freezed_annotation/freezed_annotation.dart';

import '../../subscription/models/subscription_models.dart';
import '../models/billing_admin_models.dart';

part 'billing_admin_state.freezed.dart';

/// Вкладки денежного стола — те же, что были в Angular-панели, плюс реквизиты
/// получателя и промокоды.
enum BillingTab { orders, user, audit, tariffs, promos, payee }

/// Черновик формы реквизитов получателя — значения полей до сохранения.
/// Поля живут в состоянии блока, а не в контроллерах: экран stateless.
@freezed
abstract class PayeeDraft with _$PayeeDraft {
  const factory PayeeDraft({
    @Default('') String accountNumber,
    @Default('') String name,
    @Default('') String address,
    @Default('289') String paymentCode,
    @Default('') String purpose,
  }) = _PayeeDraft;

  const PayeeDraft._();

  factory PayeeDraft.fromPayee(Payee payee) => PayeeDraft(
    accountNumber: payee.accountDisplay.isEmpty
        ? payee.accountNumber
        : payee.accountDisplay,
    name: payee.name,
    address: payee.address ?? '',
    paymentCode: payee.paymentCode,
    purpose: payee.purpose,
  );

  bool get canSave => accountNumber.trim().isNotEmpty && name.trim().isNotEmpty;
}

/// Состояние денежного стола: по блоку данных на вкладку. Каждый блок грузится
/// при первом заходе на вкладку и держится в состоянии — переключение вкладок
/// не перезапрашивает уже загруженное.
@freezed
abstract class BillingAdminState with _$BillingAdminState {
  const factory BillingAdminState({
    @Default(BillingTab.orders) BillingTab tab,

    // --- заказы
    @Default(true) bool ordersLoading,
    @Default(<Order>[]) List<Order> orders,
    @Default(0) int ordersTotal,
    @Default(0) int ordersOffset,
    @Default(50) int ordersPageSize,
    OrderStatus? statusFilter,
    @Default('') String search,

    /// Текст в поле поиска до нажатия «Найти».
    @Default('') String searchDraft,

    // --- пользователь
    @Default(false) bool userLoading,
    @Default('') String userEmail,
    @Default('') String userEmailDraft,
    BillingUser? user,
    @Default(false) bool userNotFound,

    // --- форма ручной выдачи
    @Default(TariffKind.basic) TariffKind grantKind,
    @Default('1') String grantMonths,
    @Default('') String grantNote,

    // --- журнал
    @Default(false) bool auditLoading,
    @Default(false) bool auditLoaded,
    @Default(<BillingAuditEntry>[]) List<BillingAuditEntry> audit,

    // --- тарифы
    @Default(false) bool tariffsLoading,
    @Default(false) bool tariffsLoaded,
    @Default(<AdminTariff>[]) List<AdminTariff> tariffs,

    /// Цены, набранные в полях, но ещё не сохранённые (по SKU).
    @Default(<String, String>{}) Map<String, String> priceDrafts,

    // --- промокоды
    @Default(false) bool promosLoading,
    @Default(false) bool promosLoaded,
    @Default(<AdminPromoCode>[]) List<AdminPromoCode> promoCodes,

    /// Последняя сгенерированная пачка — показывается сверху для копирования.
    @Default(<AdminPromoCode>[]) List<AdminPromoCode> generatedPromoCodes,

    // --- форма генерации промокодов
    @Default('10') String promoCount,
    @Default('10') String promoDiscount,
    DateTime? promoValidUntil,

    /// SKU, к которому привязываются коды; `null` — ко всем тарифам.
    String? promoSku,
    @Default('') String promoNote,

    // --- получатель
    @Default(false) bool payeeLoading,
    Payee? payee,
    @Default(PayeeDraft()) PayeeDraft payeeDraft,

    /// Идёт мутация — кнопки действий на это время выключены.
    @Default(false) bool submitting,

    /// Одноразовые сообщения для снэкбара; сбрасываются следующим событием.
    String? errorMessage,
    String? infoMessage,
  }) = _BillingAdminState;

  const BillingAdminState._();

  bool get hasPrevPage => ordersOffset > 0;

  /// Срок ручной выдачи/продления, если в поле разумное число.
  int? get grantMonthsValue {
    final n = int.tryParse(grantMonths.trim());
    return n == null || n < 1 || n > 120 ? null : n;
  }

  bool get hasNextPage => ordersOffset + orders.length < ordersTotal;

  /// Сколько кодов генерировать, если в поле разумное число (1–200).
  int? get promoCountValue {
    final n = int.tryParse(promoCount.trim());
    return n == null || n < 1 || n > 200 ? null : n;
  }

  /// Скидка генерируемых кодов, если в поле разумное число (1–100).
  int? get promoDiscountValue {
    final n = int.tryParse(promoDiscount.trim());
    return n == null || n < 1 || n > 100 ? null : n;
  }

  /// Форма генерации заполнена корректно.
  bool get canGeneratePromos =>
      promoCountValue != null &&
      promoDiscountValue != null &&
      promoValidUntil != null;

  /// Реквизиты не введены — заказы уходят без уплатницы; стол показывает
  /// предупреждение поверх списка.
  bool get payeeMissing => payee != null && !payee!.configured;
}
