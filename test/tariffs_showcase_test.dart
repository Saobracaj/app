import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/state_management/subscription_state.dart';

/// Тариф каталога — с идентификаторами товаров сторов, как их отдаёт бэкенд.
/// Автопродление ровно у месячного: 3 и 12 месяцев платятся один раз.
Tariff tariff(String sku, int months, int priceRsd) => Tariff(
  sku: sku,
  months: months,
  priceRsd: priceRsd,
  appleProductId: 'at.gleb.saobracaj.$sku',
  googleProductId: sku,
  autoRenewing: months == 1,
);

/// Арифметика витрины: какие пропуска показаны, какой выделен и во сколько
/// раз длинный срок дешевле помесячной оплаты.
void main() {
  // Каталог из `TARIFF_SEED` (saobracaj_backend/src/billing/model.rs).
  final catalog = [
    tariff('premium_12m', 12, 4490),
    tariff('premium_1m', 1, 1490),
    tariff('premium_3m', 3, 2990),
  ];

  final state = SubscriptionState(tariffs: catalog, inProgress: false);

  group('offeredTariffs', () {
    test('показывает один ряд сроков по возрастанию', () {
      expect(state.offeredTariffs.map((t) => t.sku), [
        'premium_1m',
        'premium_3m',
        'premium_12m',
      ]);
    });

    test('выделен трёхмесячный, а без него — самый длинный', () {
      expect(state.recommendedTariff?.sku, 'premium_3m');
      final noQuarter = SubscriptionState(
        inProgress: false,
        tariffs: [
          tariff('premium_1m', 1, 1490),
          tariff('premium_12m', 12, 4490),
        ],
      );
      expect(noQuarter.recommendedTariff?.sku, 'premium_12m');
      expect(const SubscriptionState().recommendedTariff, isNull);
    });
  });

  group('экономия против помесячной оплаты', () {
    test('три месяца стоят как два месячных', () {
      final quarter = state.offeredTariffs[1];
      expect(state.savingPercent(quarter), 33);
      expect(state.savingRsd(quarter), 1490 * 3 - 2990);
    });

    test('годовой дешевле на 75%', () {
      final yearly = state.offeredTariffs.last;
      expect(state.savingPercent(yearly), 75);
      expect(state.savingRsd(yearly), 1490 * 12 - 4490);
    });

    test('месячному сравнивать себя не с чем', () {
      final monthly = state.offeredTariffs.first;
      expect(state.savingPercent(monthly), isNull);
      expect(state.savingRsd(monthly), isNull);
    });

    test('без месячного тарифа экономия не выдумывается', () {
      final noMonthly = SubscriptionState(
        inProgress: false,
        tariffs: [tariff('premium_12m', 12, 4490)],
      );
      expect(noMonthly.savingPercent(noMonthly.offeredTariffs.single), isNull);
    });
  });

  // Рядом с ценой на карточке стоит сумма экономии, и валюта у них должна быть
  // одна: экономия в динарах под ценой в евро — три числа, которые не
  // складываются.
  group('экономия считается в тех же деньгах, что и цены', () {
    StoreProduct product(String id, double price) => StoreProduct(
      id: id,
      price: '$price',
      rawPrice: price,
      currencyCode: 'EUR',
    );

    final withStore = state.copyWith(
      storeProducts: {
        'premium_1m': product('premium_1m', 12.99),
        'premium_3m': product('premium_3m', 24.99),
        'premium_12m': product('premium_12m', 37.99),
      },
    );

    test('по ценам стора, когда стор их назвал', () {
      final yearly = withStore.offeredTariffs.last;
      final saving = withStore.saving(yearly, StorePlatform.google);
      expect(saving?.currencyCode, 'EUR');
      expect(saving?.amount, closeTo(12.99 * 12 - 37.99, 1e-9));
    });

    test('в справочных динарах, когда цен стора нет', () {
      final yearly = state.offeredTariffs.last;
      final saving = state.saving(yearly, null);
      // Валюты нет — значит динары, и подписать сумму надо ими.
      expect(saving?.currencyCode, isNull);
      expect(saving?.amount, 1490 * 12 - 4490);
    });

    test('месячному сравнивать себя не с чем', () {
      expect(
        withStore.saving(withStore.offeredTariffs.first, StorePlatform.google),
        isNull,
      );
    });

    // Цены стора живут своей жизнью: если длинный пропуск там дороже, чем те же
    // месяцы помесячно, «экономию» показывать нельзя.
    test('отрицательная экономия не показывается', () {
      final overpriced = state.copyWith(
        storeProducts: {
          'premium_1m': product('premium_1m', 1.0),
          'premium_12m': product('premium_12m', 99.0),
        },
      );
      expect(
        overpriced.saving(overpriced.offeredTariffs.last, StorePlatform.google),
        isNull,
      );
    });
  });
}
