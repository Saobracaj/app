import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/analytics/analytics_event_sink.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Приёмник событий аналитики: пачки, дедупликация по клиентскому id и то, что
/// неудачная отправка не теряет события.

class _RecordingClient extends GraphqlClient {
  _RecordingClient(super.storage);

  /// Сколько первых вызовов должны упасть — так проверяется возврат пачки в
  /// очередь.
  int failTimes = 0;

  /// Отправленные пачки: каждая — список событий в том виде, в каком они ушли
  /// бы на сервер.
  final List<List<Map<String, dynamic>>> batches = [];

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    if (failTimes > 0) {
      failTimes--;
      throw GraphqlException('нет сети', network: true);
    }
    final events = (variables['events'] as List)
        .cast<Map<String, dynamic>>()
        .toList();
    batches.add(events);
    return {'trackEvents': events.length};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingClient client;
  late AnalyticsEventSink sink;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = _RecordingClient(TokenStorage());
    sink = AnalyticsEventSink(
      client,
      TokenStorage(),
      // Таймер в тестах не нужен: отправка вызывается вручную или по размеру
      // пачки.
      flushInterval: const Duration(days: 1),
      batchSize: 3,
      maxBuffered: 5,
    );
    await sink.start();
  });

  tearDown(() => sink.stop());

  test('пачка уходит сама, когда событий накопилось достаточно', () async {
    sink.add('question_viewed', {'question_id': 1});
    sink.add('question_viewed', {'question_id': 2});
    expect(client.batches, isEmpty, reason: 'до порога ничего не отправляется');
    sink.add('question_viewed', {'question_id': 3});
    await Future<void>.delayed(Duration.zero);

    expect(client.batches.length, 1);
    expect(client.batches.single.length, 3);
    expect(sink.pendingCount, 0);
  });

  test('событие несёт всё, что нужно для выборки по пользователю', () async {
    sink.setScreen('/question/:id');
    sink.add('question_tab_opened', {'tab': 'zakon', 'question_id': 812});
    await sink.flush();

    final event = client.batches.single.single;
    expect(event['name'], 'question_tab_opened');
    expect(event['params'], {'tab': 'zakon', 'question_id': 812});
    expect(event['screen'], '/question/:id');
    expect(event['sessionId'], sink.sessionId);
    expect((event['deviceId'] as String).isNotEmpty, isTrue);
    expect((event['id'] as String).isNotEmpty, isTrue);
    // Время — в UTC и в формате, который принимает бэкенд.
    expect(DateTime.parse(event['occurredAt'] as String).isUtc, isTrue);
  });

  test('идентификаторы событий уникальны — повтор пачки ничего не задваивает', () async {
    sink.add('a', const {});
    sink.add('b', const {});
    await sink.flush();

    final ids = client.batches.single.map((e) => e['id']).toSet();
    expect(ids.length, 2);
  });

  test('неудачная отправка возвращает события в очередь', () async {
    client.failTimes = 1;
    sink.add('question_viewed', {'question_id': 1});
    await sink.flush();
    expect(client.batches, isEmpty);
    expect(sink.pendingCount, 1, reason: 'событие осталось ждать связи');

    await sink.flush();
    expect(client.batches.single.single['params'], {'question_id': 1});
    expect(sink.pendingCount, 0);
  });

  test('очередь не растёт без предела: старое вытесняется', () async {
    client.failTimes = 100;
    for (var i = 0; i < 12; i++) {
      sink.add('question_viewed', {'question_id': i});
      await Future<void>.delayed(Duration.zero);
    }
    expect(sink.pendingCount, 5, reason: 'потолок очереди — maxBuffered');

    client.failTimes = 0;
    await sink.flush();
    final ids = client.batches.single
        .map((e) => (e['params'] as Map)['question_id'])
        .toList();
    expect(ids, [7, 8, 9, 10, 11], reason: 'выброшены самые старые');
  });
}
