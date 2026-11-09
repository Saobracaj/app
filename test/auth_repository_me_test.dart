import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JWT с заданным сроком — клиент читает только `exp`, подпись не проверяет.
String _jwt(Duration fromNow) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().toUtc().add(fromNow).millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256'})}.${seg({'sub': 'u1', 'exp': exp})}.sig';
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final List<Object> responses;
  final List<String> operations = [];
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final query = (options.data as Map)['query'].toString();
    final name = RegExp(r'^\s*(?:query|mutation)\s+(\w+)').firstMatch(query);
    operations.add(name?.group(1) ?? query.trim());
    authHeaders.add(options.headers['Authorization'] as String?);
    if (responses.isEmpty) {
      throw StateError('лишний запрос: ${operations.last}');
    }
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

const _nobody = {
  'data': {'me': null},
};

const _viewer = {
  'data': {
    'me': {'id': 'u1', 'email': 'a@b.c', 'permissions': <String>[]},
  },
};

Map<String, dynamic> _refreshResponse(String access) => {
  'data': {
    'refreshToken': {
      'accessToken': access,
      'refreshToken': _jwt(const Duration(days: 30)),
      'authenticated': true,
    },
  },
};

void _signedIn() {
  SharedPreferences.setMockInitialValues({
    'auth_access_token': _jwt(const Duration(minutes: 20)),
    'auth_refresh_token': _jwt(const Duration(days: 20)),
  });
}

({GraphqlClient client, AuthRepository repository}) _build(
  _FakeAdapter adapter,
) {
  final storage = TokenStorage();
  final client = GraphqlClient(
    storage,
    dio: Dio()..httpClientAdapter = adapter,
  );
  return (
    client: client,
    repository: AuthRepository(client, storage, AnalyticsService()),
  );
}

/// `me` на бэкенде не защищён guard-ом: токен, который сервер не признал,
/// делает запрос анонимным, и ответ — `null`, как у удалённого аккаунта.
/// AuthBloc по такому `null` разлогинивает, поэтому репозиторий сперва
/// обновляет токен и спрашивает ещё раз.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('me == null при живом по часам токене: обновить и переспросить', () async {
    _signedIn();
    final fresh = _jwt(const Duration(minutes: 30));
    final adapter = _FakeAdapter([_nobody, _refreshResponse(fresh), _viewer]);
    final (:client, :repository) = _build(adapter);

    final viewer = await repository.me();

    expect(viewer?.id, 'u1');
    expect(adapter.operations, ['Me', 'Refresh', 'Me']);
    expect(adapter.authHeaders.last, 'Bearer $fresh');
  });

  test('null и со свежим токеном — аккаунта действительно нет', () async {
    _signedIn();
    final adapter = _FakeAdapter([
      _nobody,
      _refreshResponse(_jwt(const Duration(minutes: 30))),
      _nobody,
    ]);
    final (:client, :repository) = _build(adapter);

    expect(await repository.me(), isNull);
    expect(adapter.operations, ['Me', 'Refresh', 'Me']);
  });

  test('гость получает null без попытки обновления', () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _FakeAdapter([_nobody]);
    final (:client, :repository) = _build(adapter);

    expect(await repository.me(), isNull);
    expect(adapter.operations, ['Me']);
    expect(adapter.authHeaders.single, isNull);
  });

  test('сбой сети при обновлении — ошибка, а не «аккаунта нет»', () async {
    _signedIn();
    final adapter = _FakeAdapter([
      _nobody,
      DioException(
        requestOptions: RequestOptions(path: '/graphql'),
        type: DioExceptionType.connectionError,
      ),
    ]);
    final (:client, :repository) = _build(adapter);
    var expired = false;
    client.sessionExpired.listen((_) => expired = true);

    // AuthBloc ловит исключение и оставляет сессию — до следующей попытки.
    await expectLater(repository.me(), throwsA(isA<GraphqlException>()));
    await Future<void>.delayed(Duration.zero);
    expect(expired, isFalse);
    expect(adapter.operations, ['Me', 'Refresh']);
  });

  test('отвергнутый refresh-токен завершает сессию как и прежде', () async {
    _signedIn();
    final adapter = _FakeAdapter([
      _nobody,
      {
        'errors': [
          {
            'message': 'token has expired',
            'extensions': {'code': 'token_expired'},
          },
        ],
      },
    ]);
    final (:client, :repository) = _build(adapter);
    final expired = client.sessionExpired.first;

    await expectLater(repository.me(), throwsA(isA<AuthExpiredException>()));
    await expired.timeout(const Duration(seconds: 1));
  });

  test('refreshSession у гостя ничего не шлёт и сессию не трогает', () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _FakeAdapter([]);
    final (:client, repository: _) = _build(adapter);
    var expired = false;
    client.sessionExpired.listen((_) => expired = true);

    expect(await client.refreshSession(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(expired, isFalse);
    expect(adapter.operations, isEmpty);
  });
}
