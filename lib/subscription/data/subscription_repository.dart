import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../feature_flags/data/feature_flags_repository.dart';
import '../models/subscription_models.dart';

/// Тарифы, покупки и подписка пользователя.
///
/// Продажа идёт **через сторы**: приложение получает чек от App Store или
/// Google Play и приносит его сюда, а бэкенд спрашивает у стора, что этот чек
/// купил. Веб только показывает состояние подписки — оформить её там нельзя.
@lazySingleton
class SubscriptionRepository {
  SubscriptionRepository(this._client, this._flags);

  final GraphqlClient _client;
  final FeatureFlagsRepository _flags;

  /// Витрина: активные тарифы. Запрос публичный — цены видно и без входа.
  Future<List<Tariff>> tariffs() async {
    final data = await _client.run(
      'query Tariffs { tariffs { ${Tariff.fields} } }',
    );
    final list = data['tariffs'] as List? ?? const [];
    return [
      for (final raw in list) Tariff.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// Текущая подписка вызывающего.
  Future<SubscriptionStatus> mySubscription() async {
    final data = await _client.run(
      'query MySubscription { mySubscription { ${SubscriptionStatus.fields} } }',
      authenticated: true,
    );
    final raw = data['mySubscription'] as Map<String, dynamic>?;
    return raw == null
        ? SubscriptionStatus.none
        : SubscriptionStatus.fromJson(raw);
  }

  /// Покупки вызывающего, новые сверху.
  Future<List<StorePurchase>> myPurchases() async {
    final data = await _client.run(
      'query MyStorePurchases { myStorePurchases { ${StorePurchase.fields} } }',
      authenticated: true,
    );
    final list = data['myStorePurchases'] as List? ?? const [];
    return [
      for (final raw in list)
        StorePurchase.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// История периодов подписки.
  Future<List<SubscriptionPeriod>> myPeriods() async {
    final data = await _client.run(
      'query MySubscriptionPeriods '
      '{ mySubscriptionPeriods { ${SubscriptionPeriod.fields} } }',
      authenticated: true,
    );
    final list = data['mySubscriptionPeriods'] as List? ?? const [];
    return [
      for (final raw in list)
        SubscriptionPeriod.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// Отдать бэкенду чек стора и получить новое состояние подписки.
  ///
  /// Вызывать можно сколько угодно раз: право записывается один раз на платёж,
  /// поэтому и повтор после обрыва связи, и «восстановить покупки» безопасны.
  Future<SubscriptionStatus> redeemPurchase({
    required StorePlatform platform,
    required String productId,
    required String receipt,
  }) async {
    final data = await _client.run(
      '''
        mutation RedeemStorePurchase(
          \$platform: StorePlatform!, \$productId: String!, \$receipt: String!
        ) {
          redeemStorePurchase(
            platform: \$platform, productId: \$productId, receipt: \$receipt
          ) { ${SubscriptionStatus.fields} }
        }
      ''',
      variables: {
        'platform': platform.wire,
        'productId': productId,
        'receipt': receipt,
      },
      authenticated: true,
    );
    return SubscriptionStatus.fromJson(
      data['redeemStorePurchase'] as Map<String, dynamic>,
    );
  }

  /// Включить/выключить письма-напоминания (транзакционные не отключаются).
  Future<SubscriptionStatus> setReminders(bool enabled) async {
    final data = await _client.run(
      '''
        mutation SetSubscriptionReminders(\$enabled: Boolean!) {
          setSubscriptionReminders(enabled: \$enabled) {
            ${SubscriptionStatus.fields}
          }
        }
      ''',
      variables: {'enabled': enabled},
      authenticated: true,
    );
    return SubscriptionStatus.fromJson(
      data['setSubscriptionReminders'] as Map<String, dynamic>,
    );
  }

  /// Перечитать премиум-гранты: оплаченная покупка открывает фичи, и без
  /// этого экран подписки показывал бы новый тариф, а сам контент оставался бы
  /// закрытым до перезапуска.
  Future<void> refreshGrants() => _flags.refreshFromBackend();
}
