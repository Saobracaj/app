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

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    lastVariables = variables;
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

    expect((input['subcategories'] as List).single['subcategory'], 'signs');
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

  test('does nothing when signed out', () async {
    SharedPreferences.setMockInitialValues({}); // no token
    await service.sync();
    expect(client.lastVariables, isNull);
  });
}
