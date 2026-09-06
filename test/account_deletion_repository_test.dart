import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/account_deletion/data/account_deletion_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отдаёт заготовленный ответ и запоминает тело последнего GraphQL-запроса,
/// чтобы тест мог проверить, что именно уходит на сервер.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.response);

  final Map<String, dynamic> response;
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastBody = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      json.encode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Поля `DeleteAccountInput` сервера (saobracaj_backend,
/// account_deletion/model.rs). Любое другое имя GraphQL отвергает целиком:
/// «Invalid value for argument "input", unknown field …».
const _serverInputFields = {
  'code',
  'deletePublicComments',
  'deleteSupportAttachments',
  'deleteSupportChat',
  'deleteGroupHistory',
  'acceptIrreversible',
  'acceptSubscriptionLoss',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('deleteAccount шлёт input ровно с полями серверной схемы', () async {
    final adapter = _FakeAdapter({
      'data': {
        'deleteAccount': {'deleted': true},
      },
    });
    final repository = AccountDeletionRepository(
      GraphqlClient(TokenStorage(), dio: Dio()..httpClientAdapter = adapter),
    );

    final deleted = await repository.deleteAccount(
      code: '773792',
      deletePublicComments: true,
      deleteChatAttachments: false,
      deleteSupportChat: true,
      deleteGroupHistory: false,
      acceptIrreversible: true,
      acceptSubscriptionLoss: true,
    );

    expect(deleted, isTrue);
    final input = Map<String, dynamic>.from(
      (adapter.lastBody!['variables'] as Map)['input'] as Map,
    );
    expect(input.keys.toSet(), _serverInputFields);
    expect(input, {
      'code': '773792',
      'deletePublicComments': true,
      'deleteSupportAttachments': false,
      'deleteSupportChat': true,
      'deleteGroupHistory': false,
      'acceptIrreversible': true,
      'acceptSubscriptionLoss': true,
    });
  });

  test(
    'deleteAccount пробрасывает ошибку сервера как GraphqlException',
    () async {
      final adapter = _FakeAdapter({
        'errors': [
          {
            'message': 'Неверный или просроченный код',
            'extensions': {'code': 'wrong_code'},
          },
        ],
      });
      final repository = AccountDeletionRepository(
        GraphqlClient(TokenStorage(), dio: Dio()..httpClientAdapter = adapter),
      );

      await expectLater(
        repository.deleteAccount(
          code: '000000',
          deletePublicComments: true,
          deleteChatAttachments: true,
          deleteSupportChat: false,
          deleteGroupHistory: true,
          acceptIrreversible: true,
          acceptSubscriptionLoss: false,
        ),
        throwsA(
          isA<GraphqlException>().having(
            (e) => e.message,
            'message',
            'Неверный или просроченный код',
          ),
        ),
      );
    },
  );
}
