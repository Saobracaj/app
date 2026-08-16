import 'package:injectable/injectable.dart' show lazySingleton;

import '../../auth/data/graphql_client.dart';
import '../../subscription/models/subscription_models.dart';
import '../models/billing_admin_models.dart';

/// Денежный стол: админские запросы и мутации биллинга. Все они закрыты
/// правом `manage_billing` на бэкенде — экран показывается только его
/// держателям, но проверяет право сервер.
@lazySingleton
class BillingAdminRepository {
  BillingAdminRepository(this._client);

  final GraphqlClient _client;

  /// Заказы, новые сверху; фильтр по статусу и поиск по позиву на број / email.
  Future<OrdersPage> orders({
    OrderStatus? status,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _client.run(
      '''
        query BillingOrders(\$status: OrderStatus, \$search: String, \$limit: Int!, \$offset: Int!) {
          billingOrders(status: \$status, search: \$search, limit: \$limit, offset: \$offset) {
            total
            items { ${Order.fields} }
          }
        }
      ''',
      variables: {
        'status': status?.name.toUpperCase(),
        'search': (search == null || search.trim().isEmpty)
            ? null
            : search.trim(),
        'limit': limit,
        'offset': offset,
      },
      authenticated: true,
    );
    final page = data['billingOrders'] as Map<String, dynamic>;
    return OrdersPage(
      items: [
        for (final raw in page['items'] as List? ?? const [])
          Order.fromJson(raw as Map<String, dynamic>),
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
            subscription { active tariffKind endsAt daysLeft remindersEnabled featureKeys }
            periods { startsAt endsAt tariffKind revokedAt source note }
            orders { ${Order.fields} }
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
      r'query AllTariffs { allTariffs { sku kind months priceRsd active } }',
      authenticated: true,
    );
    return [
      for (final raw in data['allTariffs'] as List? ?? const [])
        AdminTariff.fromJson(raw as Map<String, dynamic>),
    ];
  }

  Future<Payee> payee() async {
    final data = await _client.run(
      'query BillingPayee { billingPayee { ${Payee.fields} } }',
      authenticated: true,
    );
    return Payee.fromJson(data['billingPayee'] as Map<String, dynamic>);
  }

  Future<Order> confirmOrder(String id) async {
    final data = await _client.run(
      'mutation ConfirmOrder(\$id: ID!) { confirmOrder(id: \$id) { ${Order.fields} } }',
      variables: {'id': id},
      authenticated: true,
    );
    return Order.fromJson(data['confirmOrder'] as Map<String, dynamic>);
  }

  Future<Order> cancelOrder(String id, {String? reason}) async {
    final data = await _client.run(
      'mutation CancelOrder(\$id: ID!, \$reason: String) { cancelOrder(id: \$id, reason: \$reason) { ${Order.fields} } }',
      variables: {'id': id, 'reason': reason},
      authenticated: true,
    );
    return Order.fromJson(data['cancelOrder'] as Map<String, dynamic>);
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

  Future<AdminTariff> updateTariff(
    String sku, {
    int? priceRsd,
    bool? active,
  }) async {
    final data = await _client.run(
      r'''
        mutation UpdateTariff($sku: String!, $priceRsd: Int, $active: Boolean) {
          updateTariff(sku: $sku, priceRsd: $priceRsd, active: $active) {
            sku kind months priceRsd active
          }
        }
      ''',
      variables: {'sku': sku, 'priceRsd': priceRsd, 'active': active},
      authenticated: true,
    );
    return AdminTariff.fromJson(data['updateTariff'] as Map<String, dynamic>);
  }

  Future<Payee> updatePayee({
    required String accountNumber,
    required String name,
    String? address,
    String? paymentCode,
    String? purpose,
  }) async {
    final data = await _client.run(
      '''
        mutation UpdateBillingPayee(\$accountNumber: String!, \$name: String!, \$address: String, \$paymentCode: String, \$purpose: String) {
          updateBillingPayee(accountNumber: \$accountNumber, name: \$name, address: \$address, paymentCode: \$paymentCode, purpose: \$purpose) {
            ${Payee.fields}
          }
        }
      ''',
      variables: {
        'accountNumber': accountNumber,
        'name': name,
        'address': address,
        'paymentCode': paymentCode,
        'purpose': purpose,
      },
      authenticated: true,
    );
    return Payee.fromJson(data['updateBillingPayee'] as Map<String, dynamic>);
  }
}
