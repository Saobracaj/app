import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/db/db.dart';
import 'package:saobracaj/statistics/statistics_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [GraphqlClient] stub that records the variables it was asked to send and
/// returns a canned `syncStatistics` payload.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  Map<String, dynamic>? lastVariables;
  Map<String, dynamic> response = {
    'syncStatistics': {
      'answers': <dynamic>[],
      'subcategories': <dynamic>[],
      'practices': <dynamic>[],
    },
  };

  /// When set, the request hangs until it is completed — lets a test act while
  /// a sync is in flight.
  Completer<void>? gate;

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    lastVariables = variables;
    await gate?.future;
    return response;
  }
}

void main() {
  late AppDatabase db;
  late _FakeClient client;
  late StatisticsSyncService service;

  setUp(() {
    // A signed-in user, so sync actually runs.
    SharedPreferences.setMockInitialValues({'auth_access_token': 'token'});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final storage = TokenStorage();
    client = _FakeClient(storage);
    service = StatisticsSyncService(db, client, storage);
  });

  tearDown(() async => db.close());

  test('uploads all local records with their generated uuids', () async {
    await db.insertAnswer(
      AnswerRecordsCompanion.insert(
        questionId: 42,
        date: DateTime.utc(2026, 1, 2, 3, 4, 5),
        isWrong: true,
      ),
    );
    await db.insertSubCategory(
      SubCategoryRecordsCompanion.insert(
        subcategory: 'signs',
        rightAnswers: 8,
        allAnswers: 10,
      ),
    );
    await db.insertPractice(
      PracticeRecordsCompanion.insert(
        points: 90,
        time: DateTime.utc(2026, 1, 3),
        mistakes: 1,
        durationSeconds: 1200,
        wrongAnswers: const Value([7]),
      ),
    );

    await service.sync();

    final input = client.lastVariables!['input'] as Map<String, dynamic>;
    final answers = input['answers'] as List;
    expect(answers, hasLength(1));
    final answer = answers.first as Map<String, dynamic>;
    expect(answer['questionId'], 42);
    expect(answer['isWrong'], true);
    expect(answer['answeredAt'], '2026-01-02T03:04:05.000Z'); // UTC ISO-8601
    expect((answer['id'] as String).isNotEmpty, true);

    final subcategory = (input['subcategories'] as List).single as Map<String, dynamic>;
    expect(subcategory['subcategory'], 'signs');
    // Stamped by the column's clientDefault when the quiz was finished.
    expect(subcategory['occurredAt'], isNotNull);
    final practice = (input['practices'] as List).single as Map<String, dynamic>;
    expect(practice['points'], 90);
    expect(practice['wrongAnswers'], [7]);
  });

  test('merges unknown server records into the local db and dedupes by uuid', () async {
    client.response = {
      'syncStatistics': {
        'answers': [
          {
            'id': 'server-a1',
            'questionId': 5,
            'answeredAt': '2026-02-01T00:00:00.000Z',
            'isWrong': false,
          },
        ],
        'subcategories': [
          {
            'id': 'server-s1',
            'subcategory': 'priority',
            'rightAnswers': 3,
            'allAnswers': 4,
          },
        ],
        'practices': [
          {
            'id': 'server-p1',
            'points': 77,
            'occurredAt': '2026-02-02T00:00:00.000Z',
            'mistakes': 2,
            'durationSeconds': 600,
            'wrongAnswers': [1, 2],
          },
        ],
      },
    };

    await service.sync();

    expect(await db.getAllAnswers(), hasLength(1));
    expect((await db.getAllSubcategoryRecords()).single.subcategory, 'priority');
    final practice = (await db.getPracticeRecords()).single;
    expect(practice.points, 77);
    expect(practice.wrongAnswers, [1, 2]);
    expect(practice.uuid, 'server-p1');

    // A second sync returning the same records must not create duplicates.
    await service.sync();
    expect(await db.getAllAnswers(), hasLength(1));
    expect(await db.getAllSubcategoryRecords(), hasLength(1));
    expect(await db.getPracticeRecords(), hasLength(1));
  });

  test('keeps subcategory timestamps as the server reports them', () async {
    client.response = {
      'syncStatistics': {
        'answers': <dynamic>[],
        'subcategories': [
          {
            'id': 'server-timed',
            'subcategory': 'priority',
            'rightAnswers': 3,
            'allAnswers': 4,
            'occurredAt': '2026-02-01T10:00:00.000Z',
          },
          // A record synced by a client older than schema v6: it has no time at
          // all, and inventing one would date it to the moment of this download.
          {
            'id': 'server-untimed',
            'subcategory': 'signs',
            'rightAnswers': 9,
            'allAnswers': 10,
            'occurredAt': null,
          },
        ],
        'practices': <dynamic>[],
      },
    };

    await service.sync();

    final records = {for (final r in await db.getAllSubcategoryRecords()) r.uuid: r};
    expect(records['server-timed']!.occurredAt, DateTime.utc(2026, 2, 1, 10).toLocal());
    expect(records['server-untimed']!.occurredAt, isNull);

    // The untimed record must stay untimed (and un-duplicated) on a re-sync.
    await service.sync();
    expect(await db.getAllSubcategoryRecords(), hasLength(2));
    final again = {for (final r in await db.getAllSubcategoryRecords()) r.uuid: r};
    expect(again['server-untimed']!.occurredAt, isNull);
  });

  test('does nothing when signed out', () async {
    SharedPreferences.setMockInitialValues({}); // no token
    await service.sync();
    expect(client.lastVariables, isNull);
  });

  test('логаут стирает всю локальную статистику и оповещает слушателей', () async {
    await _seedOneOfEach(db);
    final refreshes = <void>[];
    final subscription = service.synced.listen(refreshes.add);
    addTearDown(subscription.cancel);

    await service.onLoggedOut();
    await pumpEventQueue();

    expect(await db.getAllAnswers(), isEmpty);
    expect(await db.getAllSubcategoryRecords(), isEmpty);
    expect(await db.getPracticeRecords(), isEmpty);
    // Экраны, держащие статистику в памяти, должны перечитать её и показать ноль.
    expect(refreshes, hasLength(1));
  });

  test('ответ сервера, пришедший после логаута, не возвращает данные обратно', () async {
    client.response = {
      'syncStatistics': {
        'answers': [
          {
            'id': 'server-a1',
            'questionId': 5,
            'answeredAt': '2026-02-01T00:00:00.000Z',
            'isWrong': false,
          },
        ],
        'subcategories': <dynamic>[],
        'practices': <dynamic>[],
      },
    };
    await _seedOneOfEach(db);

    // Синхронизация уходит на сервер, и пока она в полёте — пользователь выходит.
    final gate = Completer<void>();
    client.gate = gate;
    final inFlight = service.sync();
    await service.onLoggedOut();
    gate.complete();
    await inFlight;

    expect(await db.getAllAnswers(), isEmpty);
    expect(await db.getAllSubcategoryRecords(), isEmpty);
    expect(await db.getPracticeRecords(), isEmpty);
  });
}

/// По одной записи в каждую таблицу статистики.
Future<void> _seedOneOfEach(AppDatabase db) async {
  await db.insertAnswer(
    AnswerRecordsCompanion.insert(
      questionId: 42,
      date: DateTime.utc(2026, 1, 2),
      isWrong: true,
    ),
  );
  await db.insertSubCategory(
    SubCategoryRecordsCompanion.insert(
      subcategory: 'signs',
      rightAnswers: 8,
      allAnswers: 10,
    ),
  );
  await db.insertPractice(
    PracticeRecordsCompanion.insert(
      points: 90,
      time: DateTime.utc(2026, 1, 3),
      mistakes: 1,
      durationSeconds: 1200,
    ),
  );
}
