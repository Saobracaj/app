import 'package:easy_localization/easy_localization.dart';

import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';

/// Общие для витрины и раздела аккаунта формулировки.
///
/// Тариф с русским описан через объём контента («конспекты и объяснения на
/// русском»), а не как наценка за язык — это осознанная формулировка, а не
/// оборот речи.
String tariffKindName(TariffKind kind) => switch (kind) {
  TariffKind.basic => LocaleKeys.subscription_kindBasic.tr(),
  TariffKind.russian => LocaleKeys.subscription_kindRussian.tr(),
};

String tariffKindSummary(TariffKind kind) => switch (kind) {
  TariffKind.basic => LocaleKeys.subscription_kindBasicSummary.tr(),
  TariffKind.russian => LocaleKeys.subscription_kindRussianSummary.tr(),
};

String monthsLabel(int months) =>
    LocaleKeys.subscription_months.plural(months);

String priceLabel(int rsd) =>
    LocaleKeys.subscription_price.tr(args: ['$rsd']);

String orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pending => LocaleKeys.subscription_statusPending.tr(),
  OrderStatus.paid => LocaleKeys.subscription_statusPaid.tr(),
  OrderStatus.cancelled => LocaleKeys.subscription_statusCancelled.tr(),
  OrderStatus.expired => LocaleKeys.subscription_statusExpired.tr(),
};

/// Дата без времени: срок подписки и срок оплаты — вопрос дня, не минуты.
String formatDate(DateTime date) => DateFormat.yMMMd().format(date);
