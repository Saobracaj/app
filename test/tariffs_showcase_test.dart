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
}
