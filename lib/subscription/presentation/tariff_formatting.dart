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

String monthsLabel(int months) => LocaleKeys.subscription_months.plural(months);

/// Сумма с разделителем разрядов по текущей локали: «3 490», а не «3490».
/// Четырёхзначные цены на витрине стоят рядом с трёхзначными, и без разделителя
/// их приходится пересчитывать глазами.
String amountLabel(int rsd) => NumberFormat.decimalPattern().format(rsd);

String priceLabel(int rsd) =>
    LocaleKeys.subscription_price.tr(args: [amountLabel(rsd)]);

/// «К оплате 3 490 RSD» — полная сумма за срок. На витрине она подписана мелко
/// под ценой за месяц: крупная цифра там — стоимость месяца, иначе годовой
/// тариф пугает суммой раньше, чем человек увидит, во сколько раз он дешевле.
String payTotalLabel(int rsd) =>
    LocaleKeys.subscription_payTotal.tr(args: [priceLabel(rsd)]);

/// Цена за месяц у тарифа на несколько месяцев — округляем до динара: дробная
/// часть в такой подписи только мешает сравнивать.
String pricePerMonthLabel(Tariff tariff) =>
    priceLabel(tariff.pricePerMonth.round());

/// Полная цена тарифа так, как её надо показать: цену стора — как есть (там
/// валюта покупателя и его налоги), а без стора — справочную в динарах.
String totalPriceLabel(Tariff tariff, StoreProduct? product) =>
    product?.price ?? priceLabel(tariff.priceRsd);

/// Цена за месяц: у товара стора делим его же сумму, иначе справочную.
///
/// Валюту при делении не пересчитываем — берём готовую строку стора и меняем
/// в ней только число, поэтому для многомесячных тарифов цена за месяц
/// показывается лишь тогда, когда стор дал разбираемую сумму.
String? perMonthLabel(Tariff tariff, StoreProduct? product) {
  if (product == null) return pricePerMonthLabel(tariff);
  if (tariff.months <= 1) return product.price;
  final perMonth = product.rawPrice / tariff.months;
  return NumberFormat.simpleCurrency(name: product.currencyCode).format(perMonth);
}

String purchaseStatusLabel(StorePurchaseStatus status) => switch (status) {
  StorePurchaseStatus.active => LocaleKeys.subscription_purchaseStatusActive.tr(),
  StorePurchaseStatus.expired =>
    LocaleKeys.subscription_purchaseStatusExpired.tr(),
  StorePurchaseStatus.refunded =>
    LocaleKeys.subscription_purchaseStatusRefunded.tr(),
};

String storePlatformName(StorePlatform platform) => switch (platform) {
  StorePlatform.apple => LocaleKeys.subscription_platformApple.tr(),
  StorePlatform.google => LocaleKeys.subscription_platformGoogle.tr(),
};

/// Дата без времени: срок подписки и срок оплаты — вопрос дня, не минуты.
String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

/// Дата со временем — для журнала и списка заказов, где важен порядок
/// операций внутри дня.
String formatDateTime(DateTime date) =>
    DateFormat.yMMMd().add_Hm().format(date);
