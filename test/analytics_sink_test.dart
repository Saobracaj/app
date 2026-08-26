import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/analytics/analytics_event_sink.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Приёмник событий аналитики (PostHog): пачки, склейка гостя с аккаунтом,
/// дедупликация по клиентскому uuid и то, что неудачная отправка не теряет
/// события — а отвергнутая по существу пачка не зацикливает очередь.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Что должно случиться со следующими отправками: null — успех.
  Object? Function()? failure;

  /// Отправленные тела `/batch/`-запросов.
  final bodies = <Map<String, Object?>>[];

  late AnalyticsEventSink sink;

  List<Map<String, Object?>> batch(int i) =>
      (bodies[i]['batch']! as List).cast<Map<String, Object?>>();

  Map<String, Object?> props(Map<String, Object?> message) =>
      (message['properties']! as Map).cast<String, Object?>();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    failure = null;
    bodies.clear();
    sink = AnalyticsEventSink(
      TokenStorage(),
      // Таймер в тестах не нужен: отправка вызывается вручную или по размеру
      // пачки.
      flushInterval: const Duration(days: 1),
      batchSize: 3,
      maxBuffered: 5,
      russianContent: () => true,
      postBatch: (body) async {
        final error = failure?.call();
        if (error != null) throw error;
        bodies.add(body);
      },
    );
    await sink.start();
  });

  tearDown(() => sink.stop());

  test('пачка уходит сама, когда событий накопилось достаточно', () async {
    sink.add('question_viewed', {'question_id': 1});
    sink.add('question_viewed', {'question_id': 2});
    expect(bodies, isEmpty, reason: 'до порога ничего не отправляется');
    sink.add('question_viewed', {'question_id': 3});
    await Future<void>.delayed(Duration.zero);

    expect(bodies.length, 1);
    expect(batch(0).length, 3);
    expect(sink.pendingCount, 0);
  });

  test('событие несёт всё, что просил оператор', () async {
    sink.setScreen('/question/:id', title: 'Обсуждение вопроса');
    sink.add('question_tab_opened', {'tab': 'zakon', 'question_id': 812});
    await sink.flush();

    expect(bodies.single['api_key'], sink.apiKey);
    final event = batch(0).single;
    expect(event['event'], 'question_tab_opened');
    final p = props(event);
    expect(p['tab'], 'zakon');
    expect(p['question_id'], 812);
    expect(p[r'$screen_name'], 'Обсуждение вопроса');
    expect(p['route'], '/question/:id');
    expect(p[r'$session_id'], sink.sessionId);
    expect(p[r'$os'], isNotEmpty);
    expect(p['locale'], isNotNull);
    expect(p['russian_content'], isTrue);
    // Гость: distinct_id — идентификатор установки.
    expect(p['distinct_id'], p[r'$device_id']);
    expect((p['distinct_id']! as String).isNotEmpty, isTrue);
    // Время — в UTC и в формате, который принимает PostHog.
    expect(DateTime.parse(event['timestamp']! as String).isUtc, isTrue);
  });

  test('вход склеивает гостя с аккаунтом, выход возвращает к установке',
      () async {
    sink.add('question_viewed', {'question_id': 1});
    sink.identify('user-1', set: {'email': 'x@y.z'});
    await Future<void>.delayed(Duration.zero);
    sink.add('question_viewed', {'question_id': 2});
    sink.clearUser();
    sink.add('question_viewed', {'question_id': 3});
    await sink.flush();

    final all = [for (var i = 0; i < bodies.length; i++) ...batch(i)];
    expect(all.length, 4);

    final guest = props(all[0]);
    final identify = props(all[1]);
    final signedIn = props(all[2]);
    final guestAgain = props(all[3]);
    final deviceId = guest['distinct_id'];

    // До входа — установка, после — аккаунт, и решается это в момент
    // события, а не отправки.
    expect(all[1]['event'], r'$identify');
    expect(identify['distinct_id'], 'user-1');
    expect(identify[r'$anon_distinct_id'], deviceId);
    expect(identify[r'$set'], {'email': 'x@y.z'});
    expect(signedIn['distinct_id'], 'user-1');
    expect(guestAgain['distinct_id'], deviceId);
  });

  test('идентификаторы событий уникальны и в формате uuid', () async {
    sink.add('a', const {});
    sink.add('b', const {});
    await sink.flush();

    final ids = batch(0).map((e) => e['uuid']! as String).toSet();
    expect(ids.length, 2);
    for (final id in ids) {
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: '$id должен быть UUIDv4',
      );
    }
  });

  test('неудачная отправка возвращает события в очередь', () async {
    var failures = 1;
    failure = () => failures-- > 0 ? Exception('нет сети') : null;
    sink.add('question_viewed', {'question_id': 1});
    await sink.flush();
    expect(bodies, isEmpty);
    expect(sink.pendingCount, 1, reason: 'событие осталось ждать связи');

    await sink.flush();
    expect(props(batch(0).single)['question_id'], 1);
    expect(sink.pendingCount, 0);
  });

  test('отвергнутая по существу пачка выбрасывается, а не зацикливается',
      () async {
    failure = () => DioException(
      requestOptions: RequestOptions(path: '/batch/'),
      response: Response(
        requestOptions: RequestOptions(path: '/batch/'),
        statusCode: 400,
      ),
    );
    sink.add('question_viewed', {'question_id': 1});
    await sink.flush();
    expect(sink.pendingCount, 0, reason: 'повтор дал бы тот же отказ');
  });

  test('очередь не растёт без предела: старое вытесняется', () async {
    failure = () => Exception('нет сети');
    for (var i = 0; i < 12; i++) {
      sink.add('question_viewed', {'question_id': i});
      await Future<void>.delayed(Duration.zero);
    }
    expect(sink.pendingCount, 5, reason: 'потолок очереди — maxBuffered');

    failure = null;
    await sink.flush();
    final ids = batch(0).map((e) => props(e)['question_id']).toList();
    expect(ids, [7, 8, 9, 10, 11], reason: 'выброшены самые старые');
  });
}
