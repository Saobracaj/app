import 'package:injectable/injectable.dart' show lazySingleton;

import '../../auth/data/graphql_client.dart';
import '../../subscription/models/subscription_models.dart';
import '../models/billing_admin_models.dart';

/// Денежный стол: админские запросы и мутации биллинга. Все они закрыты
/// правом `manage_billing` на бэкенде — экран показывается только его
/// держателям, но проверяет право сервер.
///
/// Подтверждать оплату больше нечего: деньги берут сторы, и право появляется
/// само по проверенному чеку. Оператору остались наблюдение (покупки, журнал),
/// ручная выдача подписки и правка каталога.
@lazySingleton
class BillingAdminRepository {
  BillingAdminRepository(this._client);

  final GraphqlClient _client;

  /// Покупки, новые сверху; фильтр по стору и поиск по email покупателя,
  /// идентификатору платежа или товару.
  Future<StorePurchasesPage> purchases({
    StorePlatform? platform,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _client.run(
      '''
        query BillingPurchases(
          \$platform: StorePlatform, \$search: String, \$limit: Int!, \$offset: Int!
        ) {
          billingPurchases(
            platform: \$platform, search: \$search, limit: \$limit, offset: \$offset
          ) {
            total
            items { ${StorePurchase.fields} }
          }
        }
      ''',
      variables: {
        'platform': platform?.wire,
        'search': (search == null || search.trim().isEmpty)
            ? null
            : search.trim(),
        'limit': limit,
        'offset': offset,
      },
      authenticated: true,
    );
    final page = data['billingPurchases'] as Map<String, dynamic>;
    return StorePurchasesPage(
      items: [
        for (final raw in page['items'] as List? ?? const [])
          StorePurchase.fromJson(raw as Map<String, dynamic>),
      ],
      total: (page['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// Карточка пользователя по email; `null`, если такого нет.
  Future<BillingUser?> user(String email) async {
    final data = await _client.run(
      '''
        query BillingUser(\$email: String!) {
          billingUser(email: \$email) {
            userId email
            subscription { ${SubscriptionStatus.fields} featureKeys }
            periods { ${SubscriptionPeriod.fields} }
            purchases { ${StorePurchase.fields} }
          }
        }
      ''',
      variables: {'email': email.trim()},
      authenticated: true,
    );
    final raw = data['billingUser'] as Map<String, dynamic>?;
    return raw == null ? null : BillingUser.fromJson(raw);
  }

  Future<List<BillingAuditEntry>> auditLog({int limit = 100}) async {
    final data = await _client.run(
      r'''
        query BillingAuditLog($limit: Int!) {
          billingAuditLog(limit: $limit) {
            id actorEmail action details createdAt
          }
        }
      ''',
      variables: {'limit': limit},
      authenticated: true,
    );
    return [
      for (final raw in data['billingAuditLog'] as List? ?? const [])
        BillingAuditEntry.fromJson(raw as Map<String, dynamic>),
    ];
  }

  Future<List<AdminTariff>> allTariffs() async {
    final data = await _client.run(
      'query AllTariffs { allTariffs { ${AdminTariff.fields} } }',
      authenticated: true,
    );
    return [
      for (final raw in data['allTariffs'] as List? ?? const [])
        AdminTariff.fromJson(raw as Map<String, dynamic>),
    ];
  }

  Future<void> grantSubscription({
    required String userId,
    required TariffKind kind,
    required int months,
    String? note,
  }) async {
    await _client.run(
      r'''
        mutation GrantSubscription($userId: ID!, $kind: TariffKind!, $months: Int!, $note: String) {
          grantSubscription(userId: $userId, kind: $kind, months: $months, note: $note) { id }
        }
      ''',
      variables: {
        'userId': userId,
        'kind': kind.name.toUpperCase(),
        'months': months,
        'note': note,
      },
      authenticated: true,
    );
  }

  Future<void> extendSubscription({
    required String userId,
    required int months,
    String? note,
  }) async {
    await _client.run(
      r'''
        mutation ExtendSubscription($userId: ID!, $months: Int!, $note: String) {
          extendSubscription(userId: $userId, months: $months, note: $note) { id }
        }
      ''',
      variables: {'userId': userId, 'months': months, 'note': note},
      authenticated: true,
    );
  }

  Future<void> revokeSubscription({
    required String userId,
    String? note,
  }) async {
    await _client.run(
      r'''
        mutation RevokeSubscription($userId: ID!, $note: String) {
          revokeSubscription(userId: $userId, note: $note) { active }
        }
      ''',
      variables: {'userId': userId, 'note': note},
      authenticated: true,
    );
  }

  /// Правка каталога: справочная цена, видимость в веб-витрине и привязка к
  /// товарам сторов. Цену, которую платит покупатель, задают консоли сторов —
  /// здесь её изменить нельзя.
  Future<AdminTariff> updateTariff(
    String sku, {
    int? priceRsd,
    bool? active,
    String? appleProductId,
    String? googleProductId,
  }) async {
    final data = await _client.run(
      '''
        mutation UpdateTariff(
          \$sku: String!, \$priceRsd: Int, \$active: Boolean,
          \$appleProductId: String, \$googleProductId: String
        ) {
          updateTariff(
            sku: \$sku, priceRsd: \$priceRsd, active: \$active,
            appleProductId: \$appleProductId, googleProductId: \$googleProductId
          ) { ${AdminTariff.fields} }
        }
      ''',
      variables: {
        'sku': sku,
        'priceRsd': priceRsd,
        'active': active,
        'appleProductId': appleProductId,
        'googleProductId': googleProductId,
      },
      authenticated: true,
    );
    return AdminTariff.fromJson(data['updateTariff'] as Map<String, dynamic>);
  }
}
