import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/state_management/subscription_state.dart';

/// Тариф каталога — с идентификаторами товаров сторов, как их отдаёт бэкенд.
/// Автопродление ровно у месячных: 6 и 12 месяцев платятся один раз.
Tariff tariff(String sku, TariffKind kind, int months, int priceRsd) => Tariff(
  sku: sku,
  kind: kind,
  months: months,
  priceRsd: priceRsd,
  appleProductId: 'at.gleb.saobracaj.$sku',
  googleProductId: sku,
  autoRenewing: months == 1,
);

/// Арифметика витрины: какие тарифы показаны, во сколько раз длинный срок
/// дешевле помесячной оплаты и сколько стоит надбавка за русский.
void main() {
  // Каталог из `TARIFF_SEED` (saobracaj_backend/src/billing/model.rs).
  final catalog = [
    tariff('basic_1m', TariffKind.basic, 1, 1190),
    tariff('basic_6m', TariffKind.basic, 6, 2290),
    tariff('basic_12m', TariffKind.basic, 12, 3990),
    tariff('russian_1m', TariffKind.russian, 1, 1690),
    tariff('russian_6m', TariffKind.russian, 6, 3490),
    tariff('russian_12m', TariffKind.russian, 12, 5790),
  ];

  final basic = SubscriptionState(tariffs: catalog, inProgress: false);
  final russian = SubscriptionState(
    tariffs: catalog,
    inProgress: false,
    withRussian: true,
  );
  group('offeredTariffs', () {
    test('показывает один ряд сроков по возрастанию', () {
      expect(basic.offeredTariffs.map((t) => t.sku), [
        'basic_1m',
        'basic_6m',
        'basic_12m',
      ]);
    });

    test('надбавка переключает семейство, а не добавляет колонку', () {
      expect(russian.offeredTariffs.map((t) => t.sku), [
        'russian_1m',
        'russian_6m',
        'russian_12m',
      ]);
    });
  });

  group('экономия против помесячной оплаты', () {
    test('годовой базовый дешевле на 72%', () {
      final yearly = basic.offeredTariffs.last;
      expect(basic.savingPercent(yearly), 72);
      expect(basic.savingRsd(yearly), 1190 * 12 - 3990);
    });

    test('годовой с русским считается от своего же месячного', () {
      final yearly = russian.offeredTariffs.last;
      expect(russian.savingPercent(yearly), 71);
      expect(russian.savingRsd(yearly), 1690 * 12 - 5790);
    });

    test('месячному сравнивать себя не с чем', () {
      final monthly = basic.offeredTariffs.first;
      expect(basic.savingPercent(monthly), isNull);
      expect(basic.savingRsd(monthly), isNull);
    });

    test('без месячного тарифа экономия не выдумывается', () {
      final noMonthly = SubscriptionState(
        inProgress: false,
        tariffs: [tariff('basic_12m', TariffKind.basic, 12, 3990)],
      );
      expect(noMonthly.savingPercent(noMonthly.offeredTariffs.single), isNull);
    });
  });

  group('надбавка за русский', () {
    test('считается на самом длинном сроке', () {
      expect(basic.russianAddonRsd, 5790 - 3990);
      // Цифра одна и та же независимо от того, включён тумблер или нет —
      // иначе выключенный тумблер называл бы одну цену, а включённый другую.
      expect(russian.russianAddonRsd, basic.russianAddonRsd);
    });

    test('без пары тарифов цена надбавки не показывается', () {
      final onlyBasic = SubscriptionState(
        inProgress: false,
        tariffs: [tariff('basic_12m', TariffKind.basic, 12, 3990)],
      );
      expect(onlyBasic.russianAddonRsd, isNull);
    });

    test('сроки разной длины не сравниваются между собой', () {
      final mismatched = SubscriptionState(
        inProgress: false,
        tariffs: [
          tariff('basic_12m', TariffKind.basic, 12, 3990),
          tariff('russian_6m', TariffKind.russian, 6, 3490),
        ],
      );
      expect(mismatched.russianAddonRsd, isNull);
    });
  });
}
