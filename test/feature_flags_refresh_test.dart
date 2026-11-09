import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JWT с заданным сроком — клиент читает только `exp`, подпись не проверяет.
String _jwt(Duration fromNow) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().toUtc().add(fromNow).millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256'})}.${seg({'sub': 'u1', 'exp': exp})}.sig';
}

/// Отдаёт заготовленные ответы по порядку и записывает, какие операции и с
/// каким заголовком Authorization ушли. Лишний запрос — ошибка теста.
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

Map<String, dynamic> _flag(String key, bool enabled) => {
  'key': key,
  'access': 'X',
  'enabled': enabled,
};

/// Так бэкенд отвечает гостю: тир signed-in выключен, премиум выключен.
final _guestFlags = [
  _flag('groups', false),
  _flag('support_chat', false),
  _flag('category_summaries', false),
  _flag('russian_content', false),
];

/// Вошедший пользователь с подпиской.
final _premiumFlags = [
  _flag('groups', true),
  _flag('support_chat', true),
  _flag('category_summaries', true),
  _flag('russian_content', true),
];

/// Вошедший пользователь, у которого подписка закончилась.
final _expiredFlags = [
  _flag('groups', true),
  _flag('support_chat', true),
  _flag('category_summaries', false),
  _flag('russian_content', false),
];

Map<String, dynamic> _flagsResponse(List<Map<String, dynamic>> flags) => {
  'data': {
    'featureFlags': {'flags': flags},
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

DioException _offline() => DioException(
  requestOptions: RequestOptions(path: '/graphql'),
  type: DioExceptionType.connectionError,
);

/// Сохранённая сессия с живым access-токеном и кэшем грантов [cached].
void _signedIn({List<String> cached = const ['category_summaries']}) {
  SharedPreferences.setMockInitialValues({
    'auth_access_token': _jwt(const Duration(minutes: 20)),
    'auth_refresh_token': _jwt(const Duration(days: 20)),
    'feature_grants': cached,
  });
}

FeatureFlagsRepository _repository(
  _FakeAdapter adapter, {
  DateTime Function()? clock,
}) {
  final storage = TokenStorage();
  return FeatureFlagsRepository(
    GraphqlClient(storage, dio: Dio()..httpClientAdapter = adapter),
    storage,
    deviceLanguage: 'ru',
    clock: clock,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('одновременные обновления грантов делят один запрос', () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _FakeAdapter([
      _flagsResponse(const []),
      _flagsResponse(const []),
    ]);
    final repository = _repository(adapter);

    // Так это и происходит на старте: `main()` просит гранты сразу, а `AuthBloc`
    // — как только опубликована сохранённая сессия.
    await Future.wait([
      repository.refreshFromBackend(),
      repository.refreshFromBackend(),
    ]);
    expect(adapter.operations, hasLength(1));

    // Более поздний запрос по-прежнему уходит на сервер.
    await repository.refreshFromBackend();
    expect(adapter.operations, hasLength(2));
  });

  group('гостевой ответ на запрос с токеном', () {
    test('не стирает кэш, а обновляет токен и переспрашивает', () async {
      _signedIn();
      final fresh = _jwt(const Duration(minutes: 30));
      final adapter = _FakeAdapter([
        _flagsResponse(_guestFlags),
        _refreshResponse(fresh),
        _flagsResponse(_premiumFlags),
      ]);
      final repository = _repository(adapter);

      await repository.bootstrap();
      await repository.refreshFromBackend();

      expect(adapter.operations, ['FeatureFlags', 'Refresh', 'FeatureFlags']);
      // Повторный запрос ушёл уже с новым токеном.
      expect(adapter.authHeaders.last, 'Bearer $fresh');
      // Применён второй, настоящий ответ — а не гостевой.
      expect(repository.snapshot.grants, {
        'category_summaries',
        'russian_content',
      });
      expect(repository.snapshot.isEnabled(AppFeature.russianContent), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('feature_grants'),
        unorderedEquals(['category_summaries', 'russian_content']),
      );
    });

    test('если сервер и после обновления отвечает как гостю — кэш остаётся', () async {
      _signedIn();
      final adapter = _FakeAdapter([
        _flagsResponse(_guestFlags),
        _refreshResponse(_jwt(const Duration(minutes: 30))),
        _flagsResponse(_guestFlags),
      ]);
      final repository = _repository(adapter);

      await repository.bootstrap();
      await repository.refreshFromBackend();

      expect(adapter.operations, ['FeatureFlags', 'Refresh', 'FeatureFlags']);
      expect(repository.snapshot.grants, {'category_summaries'});
      expect(
        repository.snapshot.isLockedForCategory(
          AppFeature.categorySummaries,
          '30',
        ),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('feature_grants'), ['category_summaries']);
    });

    test('сбой сети при обновлении токена тоже оставляет кэш', () async {
      _signedIn();
      final adapter = _FakeAdapter([_flagsResponse(_guestFlags), _offline()]);
      final repository = _repository(adapter);

      await repository.bootstrap();
      await repository.refreshFromBackend();

      expect(adapter.operations, ['FeatureFlags', 'Refresh']);
      expect(repository.snapshot.grants, {'category_summaries'});
    });

    test('у гостя без токена гостевой ответ — обычный ответ', () async {
      SharedPreferences.setMockInitialValues({});
      final adapter = _FakeAdapter([_flagsResponse(_guestFlags)]);
      final repository = _repository(adapter);

      await repository.bootstrap();
      await repository.refreshFromBackend();

      // Обновлять нечего: токена не было, второго запроса нет.
      expect(adapter.operations, ['FeatureFlags']);
      expect(repository.snapshot.grants, isEmpty);
    });
  });

  test('истёкшая подписка снимает гранты и чистит кэш', () async {
    _signedIn();
    final adapter = _FakeAdapter([_flagsResponse(_expiredFlags)]);
    final repository = _repository(adapter);

    await repository.bootstrap();
    expect(repository.snapshot.grants, {'category_summaries'}); // из кэша
    await repository.refreshFromBackend();

    // Ответ настоящего вошедшего пользователя (тир signed-in включён) без
    // премиума — это именно «грантов нет», а не «сервер нас не узнал».
    expect(repository.snapshot.grants, isEmpty);
    expect(
      repository.snapshot.isLockedForCategory(
        AppFeature.categorySummaries,
        '30',
      ),
      isTrue,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('feature_grants'), isEmpty);
  });

  group('refreshIfStale', () {
    test('в окне свежести не переспрашивает, по его истечении — да', () async {
      _signedIn();
      var now = DateTime.utc(2026, 11, 10, 12);
      final adapter = _FakeAdapter([
        _flagsResponse(_expiredFlags),
        _flagsResponse(_premiumFlags),
      ]);
      final repository = _repository(adapter, clock: () => now);

      await repository.bootstrap();
      await repository.refreshFromBackend();
      expect(adapter.operations, hasLength(1));

      // Возврат из фона и показ замка сразу после старта — бесплатны.
      await repository.refreshIfStale(reason: 'resume');
      await repository.refreshIfStale(reason: 'locked_content');
      expect(adapter.operations, hasLength(1));

      now = now.add(FeatureFlagsRepository.staleAfter);
      await repository.refreshIfStale(reason: 'locked_content');
      expect(adapter.operations, hasLength(2));
      // И пришедшие гранты применены — замок на экране уйдёт сам.
      expect(repository.snapshot.grants, contains('category_summaries'));
    });

    test('гостю не о чем спрашивать', () async {
      SharedPreferences.setMockInitialValues({});
      final adapter = _FakeAdapter([]);
      final repository = _repository(adapter);

      await repository.bootstrap();
      await repository.refreshIfStale(reason: 'resume');

      expect(adapter.operations, isEmpty);
    });
  });

  group('reconcileContentLock', () {
    test('ответ бэкенда, расходящийся с кэшем, обновляет гранты', () async {
      _signedIn(cached: const []);
      var now = DateTime.utc(2026, 11, 10, 12);
      final adapter = _FakeAdapter([
        _flagsResponse(_expiredFlags),
        _flagsResponse(_premiumFlags),
      ]);
      final repository = _repository(adapter, clock: () => now);
      await repository.bootstrap();
      await repository.refreshFromBackend();
      expect(repository.snapshot.grants, isEmpty);
      now = now.add(FeatureFlagsRepository.mismatchStaleAfter);

      // Бэкенд прислал превью платной категории — кэш того и ждал.
      await repository.reconcileContentLock(
        AppFeature.categorySummaries,
        '30',
        locked: true,
      );
      // Бесплатная категория открыта всем — тоже без расхождения.
      await repository.reconcileContentLock(
        AppFeature.questionComments,
        '25',
        locked: false,
      );
      // Категория неизвестна — предсказать нечего.
      await repository.reconcileContentLock(
        AppFeature.questionComments,
        null,
        locked: false,
      );
      expect(adapter.operations, hasLength(1));

      // А вот полный текст платной категории при пустом кэше — расхождение:
      // пропуск куплен, кэш отстал. Гранты перечитываются сразу.
      await repository.reconcileContentLock(
        AppFeature.categorySummaries,
        '30',
        locked: false,
      );
      expect(adapter.operations, hasLength(2));
      expect(repository.snapshot.grants, contains('category_summaries'));
    });

    test('несколько документов подряд — одно обновление', () async {
      _signedIn(cached: const []);
      var now = DateTime.utc(2026, 11, 10, 12);
      final adapter = _FakeAdapter([
        _flagsResponse(_expiredFlags),
        _flagsResponse(_expiredFlags),
      ]);
      final repository = _repository(adapter, clock: () => now);
      await repository.bootstrap();
      await repository.refreshFromBackend();
      now = now.add(FeatureFlagsRepository.mismatchStaleAfter);

      // Сервер (по какой-то причине) открыл текст, а гранты не выдал: экран с
      // тремя объяснениями не должен трижды ходить за флагами.
      for (var i = 0; i < 3; i++) {
        await repository.reconcileContentLock(
          AppFeature.questionComments,
          '30',
          locked: false,
        );
      }
      expect(adapter.operations, hasLength(2));
    });
  });
}
