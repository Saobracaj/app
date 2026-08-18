import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_batch.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отдаёт заготовленные ответы по порядку и запоминает все запросы.
///
/// Первый запрос можно задержать ([hold]) — так тест воспроизводит ровно ту
/// ситуацию, ради которой склейка и сделана: пока один запрос в пути, рядом
/// выпускаются другие.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses, {this.hold});

  final List<Object> responses;
  final Completer<void>? hold;

  /// Срабатывает, когда первый запрос дошёл до «сервера».
  final Completer<void> firstArrived = Completer<void>();

  final List<Map<String, dynamic>> requests = [];

  String queryOf(int index) => requests[index]['query'] as String;

  Map<String, dynamic> variablesOf(int index) =>
      Map<String, dynamic>.from(requests[index]['variables'] as Map);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(Map<String, dynamic>.from(options.data as Map));
    if (requests.length == 1) {
      if (!firstArrived.isCompleted) firstArrived.complete();
      if (hold != null) await hold!.future;
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

GraphqlClient _client(_FakeAdapter adapter) =>
    GraphqlClient(TokenStorage(), dio: Dio()..httpClientAdapter = adapter);

const _ping = 'query Ping { __typename }';
const _me = 'query Me { me { id email } }';
const _flags = 'query FeatureFlags { featureFlags { flags { key enabled } } }';

/// Ответ на «занимающий линию» первый запрос.
Map<String, dynamic> get _pong => {
  'data': {'__typename': 'Query'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('склейка запросов', () {
    test('свободная линия — запрос уходит сразу и без изменений', () async {
      final adapter = _FakeAdapter([
        {
          'data': {'me': null},
        },
      ]);

      final data = await _client(adapter).run(_me);

      expect(adapter.requests, hasLength(1));
      expect(adapter.queryOf(0), _me);
      expect(data, {'me': null});
    });

    test('последовательные запросы не ждут друг друга', () async {
      final adapter = _FakeAdapter([
        {
          'data': {'me': null},
        },
        {
          'data': {'featureFlags': null},
        },
      ]);
      final client = _client(adapter);

      await client.run(_me);
      await client.run(_flags);

      // Ни один не задержан ради склейки: цепочка зависимых запросов работает
      // ровно как раньше.
      expect(adapter.requests, hasLength(2));
      expect(adapter.queryOf(0), _me);
      expect(adapter.queryOf(1), _flags);
    });

    test('запросы, выпущенные во время другого, уходят одним', () async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter([
        _pong,
        {
          'data': {
            '_b0_me': {'id': '1', 'email': 'a@b.c'},
            '_b1_featureFlags': {
              'flags': [
                {'key': 'x', 'enabled': true},
              ],
            },
          },
        },
      ], hold: gate);
      final client = _client(adapter);

      final busy = client.run(_ping);
      await adapter.firstArrived.future;
      final me = client.run(_me);
      final flags = client.run(_flags);
      gate.complete();
      final results = await Future.wait([busy, me, flags]);

      expect(adapter.requests, hasLength(2));
      expect(adapter.queryOf(1), contains('_b0_me: me'));
      expect(adapter.queryOf(1), contains('_b1_featureFlags: featureFlags'));
      // Каждый вызывающий получает свои данные без префиксов.
      expect(results[1], {
        'me': {'id': '1', 'email': 'a@b.c'},
      });
      expect(results[2], {
        'featureFlags': {
          'flags': [
            {'key': 'x', 'enabled': true},
          ],
        },
      });
    });

    test('переменные с одинаковыми именами не конфликтуют', () async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter([
        _pong,
        {
          'data': {'_b0_group': 'первая', '_b1_group': 'вторая'},
        },
      ], hold: gate);
      final client = _client(adapter);

      final busy = client.run(_ping);
      await adapter.firstArrived.future;
      final first = client.run(
        r'query G($id: ID!) { group(id: $id) }',
        variables: {'id': '1'},
      );
      final second = client.run(
        r'query G2($id: ID!) { group(id: $id) }',
        variables: {'id': '2'},
      );
      gate.complete();
      final results = await Future.wait([busy, first, second]);

      expect(adapter.requests, hasLength(2));
      expect(adapter.variablesOf(1), {'_b0_id': '1', '_b1_id': '2'});
      expect(adapter.queryOf(1), contains(r'$_b0_id: ID!'));
      expect(adapter.queryOf(1), contains(r'$_b1_id: ID!'));
      expect(results[1], {'group': 'первая'});
      expect(results[2], {'group': 'вторая'});
    });

    test('одинаковые запросы спрашиваются один раз', () async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter([
        _pong,
        {
          'data': {
            '_b0_featureFlags': {'flags': []},
            '_b1_me': {'id': '1'},
          },
        },
      ], hold: gate);
      final client = _client(adapter);

      final busy = client.run(_ping);
      await adapter.firstArrived.future;
      final flagsOnce = client.run(_flags);
      final flagsTwice = client.run(_flags);
      final me = client.run(_me);
      gate.complete();
      final results = await Future.wait([busy, flagsOnce, flagsTwice, me]);

      expect(adapter.requests, hasLength(2));
      // Второй `featureFlags` не добавил в документ третьего поля.
      expect(adapter.queryOf(1).contains('_b2_'), isFalse);
      expect(results[1], {
        'featureFlags': {'flags': []},
      });
      expect(results[2], results[1]);
      expect(results[3], {
        'me': {'id': '1'},
      });
    });

    test('мутация не ждёт и не склеивается', () async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter([
        _pong,
        {
          'data': {'setDisplayName': true},
        },
        {
          'data': {'me': null},
        },
      ], hold: gate);
      final client = _client(adapter);

      final busy = client.run(_ping);
      await adapter.firstArrived.future;
      // Мутация уходит немедленно, хотя линия занята; запрос — ждёт её.
      final mutation = client.run(
        r'mutation SetName($name: String!) { setDisplayName(displayName: $name) }',
        variables: {'name': 'Гость'},
      );
      final me = client.run(_me);
      gate.complete();
      await Future.wait([busy, mutation, me]);

      expect(adapter.requests, hasLength(3));
      expect(adapter.queryOf(1), startsWith('mutation'));
      expect(adapter.queryOf(2), _me);
    });

    test('batchQueries: false выключает склейку целиком', () async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter([
        _pong,
        {
          'data': {'me': null},
        },
        {
          'data': {'featureFlags': null},
        },
      ], hold: gate);
      final client = GraphqlClient(
        TokenStorage(),
        dio: Dio()..httpClientAdapter = adapter,
        batchQueries: false,
      );

      final busy = client.run(_ping);
      await adapter.firstArrived.future;
      final me = client.run(_me);
      final flags = client.run(_flags);
      gate.complete();
      await Future.wait([busy, me, flags]);

      expect(adapter.requests, hasLength(3));
      expect(adapter.queryOf(1), _me);
      expect(adapter.queryOf(2), _flags);
    });

    test('очередь длиннее лимита едет несколькими документами', () async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter([
        _pong,
        {
          'data': {'_b0_a': 1, '_b1_a': 2},
        },
        {
          'data': {'a': 3},
        },
      ], hold: gate);
      final client = GraphqlClient(
        TokenStorage(),
        dio: Dio()..httpClientAdapter = adapter,
        maxBatchSize: 2,
      );

      final busy = client.run(_ping);
      await adapter.firstArrived.future;
      final queued = [
        for (var i = 0; i < 3; i++) client.run('query Q$i { a }'),
      ];
      gate.complete();
      final results = await Future.wait([busy, ...queued]);

      expect(adapter.requests, hasLength(3));
      expect(results[1], {'a': 1});
      expect(results[2], {'a': 2});
      expect(results[3], {'a': 3});
    });
  });

  group('ошибки в склеенном ответе', () {
    /// Занимает линию первым запросом, выпускает [queries] пока она занята и
    /// возвращает их исходы (значение либо пойманное исключение).
    Future<(List<Object?>, _FakeAdapter)> runBatch(
      List<Object> responses,
      List<String> queries,
    ) async {
      final gate = Completer<void>();
      final adapter = _FakeAdapter([_pong, ...responses], hold: gate);
      final client = _client(adapter);
      final busy = client.run(_ping);
      await adapter.firstArrived.future;
      final futures = [
        for (final query in queries)
          client.run(query).then<Object?>((v) => v).catchError((Object e) => e),
      ];
      gate.complete();
      await busy;
      return (await Future.wait(futures), adapter);
    }

    test('ошибка одного поля не задевает соседей', () async {
      final (results, adapter) = await runBatch(
        [
          {
            'data': {
              '_b0_me': null,
              '_b1_featureFlags': {'flags': []},
            },
            'errors': [
              {
                'message': 'Требуется авторизация',
                'path': ['_b0_me'],
                'extensions': {'code': 'authorization_required'},
              },
            ],
          },
        ],
        [_me, _flags],
      );

      expect(
        results[0],
        isA<GraphqlException>()
            .having((e) => e.code, 'code', 'authorization_required')
            .having((e) => e.message, 'message', 'Требуется авторизация'),
      );
      expect(results[1], {
        'featureFlags': {'flags': []},
      });
      expect(adapter.requests, hasLength(2));
    });

    test('ошибка без path — запросы переспрашиваются по одному', () async {
      final (results, adapter) = await runBatch(
        [
          {
            'errors': [
              {'message': 'Unknown field "_b0_me"'},
            ],
          },
          {
            'data': {'me': null},
          },
          {
            'data': {'featureFlags': null},
          },
        ],
        [_me, _flags],
      );

      // Склейка не удалась, но вызывающие получили корректные ответы.
      expect(adapter.requests, hasLength(4));
      expect(adapter.queryOf(2), _me);
      expect(adapter.queryOf(3), _flags);
      expect(results[0], {'me': null});
      expect(results[1], {'featureFlags': null});
    });

    test('данные, потерянные из-за соседа, запрашиваются заново', () async {
      // Non-null поле соседа упало — сервер обнулил весь `data`.
      final (results, adapter) = await runBatch(
        [
          {
            'data': null,
            'errors': [
              {
                'message': 'Требуется авторизация',
                'path': ['_b0_myGroups'],
                'extensions': {'code': 'forbidden'},
              },
            ],
          },
          {
            'data': {'featureFlags': null},
          },
        ],
        ['query MyGroups { myGroups { id } }', _flags],
      );

      expect(results[0], isA<GraphqlException>());
      expect(results[1], {'featureFlags': null});
      expect(adapter.requests, hasLength(3));
      expect(adapter.queryOf(2), _flags);
    });

    test('обрыв связи достаётся всем участникам склейки', () async {
      final (results, adapter) = await runBatch(
        [
          DioException(
            requestOptions: RequestOptions(path: '/graphql'),
            type: DioExceptionType.connectionError,
          ),
        ],
        [_me, _flags],
      );

      for (final result in results) {
        expect(
          result,
          isA<GraphqlException>().having((e) => e.network, 'network', true),
        );
      }
      expect(adapter.requests, hasLength(2));
    });
  });

  group('разбор документа', () {
    test('склеиваются только простые запросы', () {
      expect(parseBatchableQuery(_me), isNotNull);
      expect(parseBatchableQuery('{ me { id } }'), isNotNull);
      expect(parseBatchableQuery('mutation M { logout }'), isNull);
      expect(parseBatchableQuery('subscription S { chat { id } }'), isNull);
      // Фрагменты пришлось бы переименовывать — такой документ не трогаем.
      expect(
        parseBatchableQuery(
          'query Q { me { ...F } } fragment F on User { id }',
        ),
        isNull,
      );
      expect(parseBatchableQuery('query Q { ...F }'), isNull);
      expect(parseBatchableQuery('   '), isNull);
    });

    test('уже существующий алиас корневого поля переименовывается', () {
      final parsed = parseBatchableQuery('query Q { viewer: me { id } }')!;
      // Ключ ответа остаётся `viewer` — префикс снимется при разборе.
      expect(parsed.selections('_b3_').trim(), '_b3_viewer: me { id }');
      expect(parsed.responseKeys, ['viewer']);
    });

    test('корневые поля получают алиас с префиксом', () {
      final parsed = parseBatchableQuery(
        'query Two { me { id } featureFlags { flags { key } } }',
      )!;
      expect(
        parsed.selections('_b0_').trim(),
        '_b0_me: me { id } _b0_featureFlags: featureFlags { flags { key } }',
      );
      expect(parsed.responseKeys, ['me', 'featureFlags']);
    });

    test('строки и комментарии не принимаются за переменные', () {
      final parsed = parseBatchableQuery(
        'query Q(\$text: String!) {\n'
        '  # \$notAVariable\n'
        '  search(text: \$text, tag: "\$literal") { id }\n'
        '}',
      )!;
      final rendered = parsed.selections('_b1_');
      expect(rendered, contains(r'text: $_b1_text'));
      expect(rendered, contains(r'tag: "$literal"'));
      expect(rendered, contains(r'# $notAVariable'));
    });

    test('склеенный документ объявляет переменные обеих операций', () {
      final merged = mergeBatchableQueries(
        [
          parseBatchableQuery(r'query A($id: ID!) { group(id: $id) { id } }')!,
          parseBatchableQuery(
            r'query B($id: Int) { question(id: $id) { id } }',
          )!,
        ],
        [
          {'id': 'g1'},
          {'id': 7},
        ],
      );

      expect(merged.prefixes, ['_b0_', '_b1_']);
      expect(
        merged.query,
        'query _Batch(\$_b0_id: ID!, \$_b1_id: Int) {\n'
        '_b0_group: group(id: \$_b0_id) { id }\n'
        '_b1_question: question(id: \$_b1_id) { id }\n'
        '}',
      );
      expect(merged.variables, {'_b0_id': 'g1', '_b1_id': 7});
    });

    test('ответ разбирается по префиксам, ошибка — по path', () {
      final prefixes = ['_b0_', '_b1_'];
      final data = {'_b0_me': 1, '_b1_me': 2};
      expect(extractBatchData(data, '_b0_'), {'me': 1});
      expect(extractBatchData(data, '_b1_'), {'me': 2});
      expect(extractBatchData(data, '_b2_'), isNull);
      expect(
        batchErrorOwner({
          'path': ['_b1_me', 'email'],
        }, prefixes),
        1,
      );
      expect(batchErrorOwner({'message': 'boom'}, prefixes), isNull);
    });
  });
}
