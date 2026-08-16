// `show` — injectable тоже экспортирует `Order` (порядок регистрации), а тут
// Order — это заказ пользователя.
import 'package:injectable/injectable.dart' show lazySingleton;

import '../../auth/data/graphql_client.dart';
import '../../feature_flags/data/feature_flags_repository.dart';
import '../models/subscription_models.dart';

/// Тарифы, заказы и подписка пользователя.
///
/// Продажа идёт **только через веб** (в мобильных сборках эти экраны не
/// зарегистрированы — требование App Store 3.1.3(b)), оплата на этой итерации
/// ручная: пользователь создаёт заказ, получает позив на број и переводит
/// деньги, оператор подтверждает платёж в панели.
@lazySingleton
class SubscriptionRepository {
  SubscriptionRepository(this._client, this._flags);

  final GraphqlClient _client;
  final FeatureFlagsRepository _flags;

  static const _orderFields = '''
    id sku tariffKind months amountRsd status referenceDisplay
    createdAt paymentDueAt
  ''';

  /// Витрина: активные тарифы. Запрос публичный — цены видно и без входа.
  Future<List<Tariff>> tariffs() async {
    final data = await _client.run(
      r'query Tariffs { tariffs { sku kind months priceRsd } }',
    );
    final list = data['tariffs'] as List? ?? const [];
    return [
      for (final raw in list) Tariff.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// Текущая подписка вызывающего.
  Future<SubscriptionStatus> mySubscription() async {
    final data = await _client.run(
      r'''
        query MySubscription {
          mySubscription { active tariffKind endsAt daysLeft remindersEnabled }
        }
      ''',
      authenticated: true,
    );
    final raw = data['mySubscription'] as Map<String, dynamic>?;
    return raw == null
        ? SubscriptionStatus.none
        : SubscriptionStatus.fromJson(raw);
  }

  /// Заказы вызывающего, новые сверху.
  Future<List<Order>> myOrders() async {
    final data = await _client.run(
      'query MyOrders { myOrders { $_orderFields } }',
      authenticated: true,
    );
    final list = data['myOrders'] as List? ?? const [];
    return [
      for (final raw in list) Order.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// История периодов подписки.
  Future<List<SubscriptionPeriod>> myPeriods() async {
    final data = await _client.run(
      r'''
        query MySubscriptionPeriods {
          mySubscriptionPeriods { startsAt endsAt tariffKind revokedAt }
        }
      ''',
      authenticated: true,
    );
    final list = data['mySubscriptionPeriods'] as List? ?? const [];
    return [
      for (final raw in list)
        SubscriptionPeriod.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// Оформить заказ на [sku]. Повторный вызов, пока заказ ещё оплачиваем,
  /// возвращает тот же заказ — второй позив на број не выпускается.
  Future<Order> createOrder(String sku) async {
    final data = await _client.run(
      'mutation CreateOrder(\$sku: String!) { createOrder(sku: \$sku) { $_orderFields } }',
      variables: {'sku': sku},
      authenticated: true,
    );
    return Order.fromJson(data['createOrder'] as Map<String, dynamic>);
  }

  /// Отменить свой неоплаченный заказ.
  Future<Order> cancelOrder(String id) async {
    final data = await _client.run(
      'mutation CancelMyOrder(\$id: ID!) { cancelMyOrder(id: \$id) { $_orderFields } }',
      variables: {'id': id},
      authenticated: true,
    );
    return Order.fromJson(data['cancelMyOrder'] as Map<String, dynamic>);
  }

  /// Включить/выключить письма-напоминания (транзакционные не отключаются).
  Future<SubscriptionStatus> setReminders(bool enabled) async {
    final data = await _client.run(
      r'''
        mutation SetSubscriptionReminders($enabled: Boolean!) {
          setSubscriptionReminders(enabled: $enabled) {
            active tariffKind endsAt daysLeft remindersEnabled
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

  /// Перечитать премиум-гранты: подтверждённая оплата открывает фичи, и без
  /// этого экран подписки показывал бы новый тариф, а сам контент оставался бы
  /// закрытым до перезапуска.
  Future<void> refreshGrants() => _flags.refreshFromBackend();
}
