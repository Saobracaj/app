import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../feature_flags/data/feature_flags_repository.dart';
import '../models/subscription_models.dart';

/// `extensions.code` отказа в счёте lava.top: подписка lava.top ещё действует
/// (пусть и отменённая); `extensions.endsAt` — до какого числа.
const lavaSubscriptionActiveCode = 'lava_subscription_active';

/// Тарифы, покупки и подписка пользователя.
///
/// Продажа идёт **через сторы**: приложение получает чек от App Store или
/// Google Play и приносит его сюда, а бэкенд спрашивает у стора, что этот чек
/// купил. В вебе стора нет — там подписку оплачивают российской картой в
/// рублях через посредника lava.top: бэкенд создаёт счёт, человек платит на
/// странице lava.top и возвращается, оплату подтверждает сам lava.top.
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

  /// Оплата рублями на сайте: создать счёт lava.top на тариф и получить
  /// страницу оплаты. [returnUrl] — куда lava.top вернёт человека после
  /// оплаты (допишет `invoiceId` и `status`).
  ///
  /// Пока действует подписка lava.top (даже отменённая), бэкенд отвечает
  /// ошибкой с кодом [lavaSubscriptionActiveCode] и датой окончания.
  Future<LavaInvoice> createLavaInvoice({
    required String sku,
    required String returnUrl,
  }) async {
    final data = await _client.run(
      '''
        mutation CreateLavaInvoice(\$sku: String!, \$returnUrl: String) {
          createLavaInvoice(sku: \$sku, returnUrl: \$returnUrl) {
            ${LavaInvoice.fields}
          }
        }
      ''',
      variables: {'sku': sku, 'returnUrl': returnUrl},
      authenticated: true,
    );
    return LavaInvoice.fromJson(
      data['createLavaInvoice'] as Map<String, dynamic>,
    );
  }

  /// Состояние счёта lava.top — его опрашивает страница возврата. Пока счёт
  /// не оплачен, бэкенд сам переспрашивает lava.top, так что запоздавший
  /// вебхук не задерживает активацию.
  Future<LavaInvoice> lavaInvoice(String id) async {
    final data = await _client.run(
      '''
        query LavaInvoice(\$id: String!) {
          lavaInvoice(id: \$id) { ${LavaInvoice.fields} }
        }
      ''',
      variables: {'id': id},
      authenticated: true,
    );
    return LavaInvoice.fromJson(data['lavaInvoice'] as Map<String, dynamic>);
  }

  /// Отменить подписку lava.top: списаний больше не будет, оплаченный период
  /// действует до конца. Возвращает новое состояние подписки.
  Future<SubscriptionStatus> cancelLavaSubscription() async {
    final data = await _client.run('''
        mutation CancelLavaSubscription {
          cancelLavaSubscription { ${SubscriptionStatus.fields} }
        }
      ''', authenticated: true);
    return SubscriptionStatus.fromJson(
      data['cancelLavaSubscription'] as Map<String, dynamic>,
    );
  }

  /// Перечитать премиум-гранты: оплаченная покупка открывает фичи, и без
  /// этого экран подписки показывал бы новый тариф, а сам контент оставался бы
  /// закрытым до перезапуска.
  Future<void> refreshGrants() => _flags.refreshFromBackend();
}
