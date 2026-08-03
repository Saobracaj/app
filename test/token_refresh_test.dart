import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A JWT with the given expiry. Only the payload matters — nothing on the
/// client verifies the signature.
String _jwt(Duration fromNow) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().toUtc().add(fromNow).millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256'})}.${seg({'sub': 'u1', 'exp': exp})}.sig';
}

/// Captures every GraphQL request and replays canned responses in order.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  /// Queued response bodies (the `data`/`errors` envelope) per request.
  final List<Object> responses;
  final List<Map<String, dynamic>> requests = [];
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(Map<String, dynamic>.from(options.data as Map));
    authHeaders.add(options.headers['Authorization'] as String?);
    final next = responses.removeAt(0);
    if (next is DioException) throw next;
    return ResponseBody.fromString(
      json.encode(next),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GraphqlClient _client(_FakeAdapter adapter, TokenStorage storage) {
  final dio = Dio()..httpClientAdapter = adapter;
  return GraphqlClient(storage, dio: dio);
}

String _operationOf(Map<String, dynamic> request) =>
    (request['query'] as String).trim();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'истёкший access-токен обновляется до запроса, а не после отказа сервера',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': _jwt(const Duration(minutes: -5)),
        'auth_refresh_token': _jwt(const Duration(days: 20)),
      });
      final storage = TokenStorage();
      final fresh = _jwt(const Duration(minutes: 30));
      final adapter = _FakeAdapter([
        {
          'data': {
            'refreshToken': {
              'accessToken': fresh,
              'refreshToken': _jwt(const Duration(days: 30)),
              'authenticated': true,
            },
          },
        },
        {
          'data': {
            'me': {'id': 'u1', 'email': 'a@b.c', 'permissions': <String>[]},
          },
        },
      ]);

      final data = await _client(
        adapter,
        storage,
      ).run('query Me { me { id } }', authenticated: true);

      expect((data['me'] as Map)['id'], 'u1');
      expect(adapter.requests.length, 2);
      expect(_operationOf(adapter.requests.first), contains('refreshToken('));
      // The real query went out with the *new* token, so `me` never resolves
      // anonymously (the back-end answers `null` instead of erroring).
      expect(adapter.authHeaders.last, 'Bearer $fresh');
      expect(await storage.accessToken, fresh);
    },
  );

  test('живой access-токен не тратит запрос на обновление', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': _jwt(const Duration(minutes: 20)),
      'auth_refresh_token': _jwt(const Duration(days: 20)),
    });
    final adapter = _FakeAdapter([
      {
        'data': {'me': null},
      },
    ]);

    await _client(
      adapter,
      TokenStorage(),
    ).run('query Me { me { id } }', authenticated: true);

    expect(adapter.requests.length, 1);
  });

  test('истёкший refresh-токен завершает сессию', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': _jwt(const Duration(minutes: -5)),
      'auth_refresh_token': _jwt(const Duration(days: -1)),
    });
    final adapter = _FakeAdapter([]);
    final client = _client(adapter, TokenStorage());
    final expired = client.sessionExpired.first;

    await expectLater(
      client.run('query Me { me { id } }', authenticated: true),
      throwsA(isA<AuthExpiredException>()),
    );
    await awaitSessionExpiry(expired);
    // Nothing was sent: a locally-expired refresh token can't be renewed.
    expect(adapter.requests, isEmpty);
  });

  test('отказ сервера в обновлении завершает сессию', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': _jwt(const Duration(minutes: -5)),
      'auth_refresh_token': _jwt(const Duration(days: 20)),
    });
    final adapter = _FakeAdapter([
      {
        'errors': [
          {
            'message': 'token has expired',
            'extensions': {'code': 'token_expired'},
          },
        ],
      },
    ]);
    final client = _client(adapter, TokenStorage());
    final expired = client.sessionExpired.first;

    await expectLater(
      client.run('query Me { me { id } }', authenticated: true),
      throwsA(isA<AuthExpiredException>()),
    );
    await awaitSessionExpiry(expired);
  });

  test('внутренняя ошибка сервера при обновлении НЕ разлогинивает', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': _jwt(const Duration(minutes: -5)),
      'auth_refresh_token': _jwt(const Duration(days: 20)),
    });
    final adapter = _FakeAdapter([
      {
        'errors': [
          {
            'message': 'internal error',
            'extensions': {'code': 'internal_error'},
          },
        ],
      },
    ]);
    final client = _client(adapter, TokenStorage());
    var expired = false;
    client.sessionExpired.listen((_) => expired = true);

    await expectLater(
      client.run('query Me { me { id } }', authenticated: true),
      throwsA(isA<GraphqlException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(expired, isFalse);
  });

  test('сетевая ошибка при обновлении НЕ разлогинивает', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': _jwt(const Duration(minutes: -5)),
      'auth_refresh_token': _jwt(const Duration(days: 20)),
    });
    final adapter = _FakeAdapter([
      DioException(
        requestOptions: RequestOptions(path: '/graphql'),
        type: DioExceptionType.connectionError,
      ),
    ]);
    final client = _client(adapter, TokenStorage());
    var expired = false;
    client.sessionExpired.listen((_) => expired = true);

    await expectLater(
      client.run('query Me { me { id } }', authenticated: true),
      throwsA(
        isA<GraphqlException>().having((e) => e.network, 'network', isTrue),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(expired, isFalse);
  });

  test('параллельные запросы обновляют токен один раз', () async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': _jwt(const Duration(minutes: -5)),
      'auth_refresh_token': _jwt(const Duration(days: 20)),
    });
    final adapter = _FakeAdapter([
      {
        'data': {
          'refreshToken': {
            'accessToken': _jwt(const Duration(minutes: 30)),
            'refreshToken': _jwt(const Duration(days: 30)),
            'authenticated': true,
          },
        },
      },
      {
        'data': {'me': null},
      },
      {
        'data': {'me': null},
      },
      {
        'data': {'me': null},
      },
    ]);
    final client = _client(adapter, TokenStorage());

    await Future.wait([
      client.run('query A { me { id } }', authenticated: true),
      client.run('query B { me { id } }', authenticated: true),
      client.run('query C { me { id } }', authenticated: true),
    ]);

    final refreshes = adapter.requests
        .where((r) => _operationOf(r).contains('refreshToken('))
        .length;
    expect(refreshes, 1);
  });

  test('гостевой запрос уходит без токена и не рушится', () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _FakeAdapter([
      {
        'data': {'me': null},
      },
    ]);

    final data = await _client(
      adapter,
      TokenStorage(),
    ).run('query Me { me { id } }', authenticated: true);

    expect(data['me'], isNull);
    expect(adapter.authHeaders.single, isNull);
  });
}

/// Awaits a `sessionExpired` event, failing the test if it never arrives.
Future<void> awaitSessionExpiry(Future<void> event) =>
    event.timeout(const Duration(seconds: 1));
