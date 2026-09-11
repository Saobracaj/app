import 'package:freezed_annotation/freezed_annotation.dart';

import '../../subscription/models/subscription_models.dart';
import '../models/billing_admin_models.dart';

part 'billing_admin_state.freezed.dart';

/// Вкладки денежного стола. Подтверждать оплату больше не нужно — деньги берут
/// сторы, — поэтому вкладок четыре: наблюдение (покупки, журнал), ручные
/// операции с подпиской и каталог.
enum BillingTab { purchases, user, audit, tariffs }

/// Состояние денежного стола: по блоку данных на вкладку. Каждый блок грузится
/// при первом заходе на вкладку и держится в состоянии — переключение вкладок
/// не перезапрашивает уже загруженное.
@freezed
abstract class BillingAdminState with _$BillingAdminState {
  const factory BillingAdminState({
    @Default(BillingTab.purchases) BillingTab tab,

    // --- покупки
    @Default(true) bool purchasesLoading,
    @Default(<StorePurchase>[]) List<StorePurchase> purchases,
    @Default(0) int purchasesTotal,
    @Default(0) int purchasesOffset,
    @Default(50) int purchasesPageSize,
    StorePlatform? platformFilter,
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

    /// Идёт мутация — кнопки действий на это время выключены.
    @Default(false) bool submitting,

    /// Одноразовые сообщения для снэкбара; сбрасываются следующим событием.
    String? errorMessage,
    String? infoMessage,
  }) = _BillingAdminState;

  const BillingAdminState._();

  bool get hasPrevPage => purchasesOffset > 0;

  bool get hasNextPage => purchasesOffset + purchases.length < purchasesTotal;

  /// Срок ручной выдачи/продления, если в поле разумное число.
  int? get grantMonthsValue {
    final n = int.tryParse(grantMonths.trim());
    return n == null || n < 1 || n > 120 ? null : n;
  }
}
