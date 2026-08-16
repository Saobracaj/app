import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/state_management/subscription_state.dart';

/// Арифметика витрины: какие тарифы показаны, во сколько раз длинный срок
/// дешевле помесячной оплаты и сколько стоит надбавка за русский.
void main() {
  // Каталог из `TARIFF_SEED` (saobracaj_backend/src/billing/model.rs).
  const catalog = [
    Tariff(sku: 'basic_1m', kind: TariffKind.basic, months: 1, priceRsd: 990),
    Tariff(sku: 'basic_6m', kind: TariffKind.basic, months: 6, priceRsd: 1990),
    Tariff(
      sku: 'basic_12m',
      kind: TariffKind.basic,
      months: 12,
      priceRsd: 3490,
    ),
    Tariff(
      sku: 'russian_1m',
      kind: TariffKind.russian,
      months: 1,
      priceRsd: 1490,
    ),
    Tariff(
      sku: 'russian_6m',
      kind: TariffKind.russian,
      months: 6,
      priceRsd: 2990,
    ),
    Tariff(
      sku: 'russian_12m',
      kind: TariffKind.russian,
      months: 12,
      priceRsd: 4990,
    ),
  ];

  const basic = SubscriptionState(tariffs: catalog, inProgress: false);
  const russian = SubscriptionState(
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
    test('годовой базовый дешевле на 71%', () {
      final yearly = basic.offeredTariffs.last;
      expect(basic.savingPercent(yearly), 71);
      expect(basic.savingRsd(yearly), 11880 - 3490);
    });

    test('годовой с русским считается от своего же месячного', () {
      final yearly = russian.offeredTariffs.last;
      expect(russian.savingPercent(yearly), 72);
      expect(russian.savingRsd(yearly), 17880 - 4990);
    });

    test('месячному сравнивать себя не с чем', () {
      final monthly = basic.offeredTariffs.first;
      expect(basic.savingPercent(monthly), isNull);
      expect(basic.savingRsd(monthly), isNull);
    });

    test('без месячного тарифа экономия не выдумывается', () {
      const noMonthly = SubscriptionState(
        inProgress: false,
        tariffs: [
          Tariff(
            sku: 'basic_12m',
            kind: TariffKind.basic,
            months: 12,
            priceRsd: 3490,
          ),
        ],
      );
      expect(noMonthly.savingPercent(noMonthly.offeredTariffs.single), isNull);
    });
  });

  group('надбавка за русский', () {
    test('считается на самом длинном сроке', () {
      expect(basic.russianAddonRsd, 4990 - 3490);
      // Цифра одна и та же независимо от того, включён тумблер или нет —
      // иначе выключенный тумблер называл бы одну цену, а включённый другую.
      expect(russian.russianAddonRsd, basic.russianAddonRsd);
    });

    test('без пары тарифов цена надбавки не показывается', () {
      const onlyBasic = SubscriptionState(
        inProgress: false,
        tariffs: [
          Tariff(
            sku: 'basic_12m',
            kind: TariffKind.basic,
            months: 12,
            priceRsd: 3490,
          ),
        ],
      );
      expect(onlyBasic.russianAddonRsd, isNull);
    });

    test('сроки разной длины не сравниваются между собой', () {
      const mismatched = SubscriptionState(
        inProgress: false,
        tariffs: [
          Tariff(
            sku: 'basic_12m',
            kind: TariffKind.basic,
            months: 12,
            priceRsd: 3490,
          ),
          Tariff(
            sku: 'russian_6m',
            kind: TariffKind.russian,
            months: 6,
            priceRsd: 2990,
          ),
        ],
      );
      expect(mismatched.russianAddonRsd, isNull);
    });
  });
}
