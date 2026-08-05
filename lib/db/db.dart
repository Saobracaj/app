import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'answer_table.dart';

part 'db.g.dart'; // генерируется

@DriftDatabase(tables: [AnswerRecords, SubCategoryRecords, PracticeRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Builds a database over an explicit executor (e.g. `NativeDatabase.memory()`)
  /// for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  Future<int> insertAnswer(AnswerRecordsCompanion entry) => into(answerRecords).insert(entry);

  Future<int> insertPractice(PracticeRecordsCompanion entity) => into(practiceRecords).insert(entity);

  Future<List<PracticeRecord>> getPracticeRecords() {
    return (select(practiceRecords)..orderBy([(t) => OrderingTerm(expression: t.time, mode: OrderingMode.desc)])).get();
  }

  Future<List<AnswerRecord>> getAllAnswers() => select(answerRecords).get();

  Future<List<SubCategoryRecord>> getAllSubcategoryRecords() => select(subCategoryRecords).get();

  Future<int> insertSubCategory(SubCategoryRecordsCompanion entry) => into(subCategoryRecords).insert(entry);

  /// The sync ids already stored in each table, so merges skip known records.
  Future<Set<String>> answerUuids() => _uuidsOf(answerRecords);
  Future<Set<String>> subcategoryUuids() => _uuidsOf(subCategoryRecords);
  Future<Set<String>> practiceUuids() => _uuidsOf(practiceRecords);

  Future<Set<String>> _uuidsOf(TableInfo table) async {
    final rows = await customSelect(
      'SELECT uuid FROM ${table.actualTableName} WHERE uuid IS NOT NULL',
      readsFrom: {table},
    ).get();
    return rows.map((r) => r.read<String>('uuid')).toSet();
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v3: the practice_records table was introduced. Coming from before v3
        // creates it with the *current* schema (already has wrong_answers + uuid).
        if (from < 3) {
          await m.createTable(practiceRecords);
        }
        // v4: practice_records gained wrong_answers (+ a data cleanup). Only when
        // the table already existed from exactly v3 — older paths created it fresh
        // above, already with the column.
        if (from == 3) {
          await customStatement('DELETE FROM practice_records WHERE duration_seconds > 2700');
          await m.addColumn(practiceRecords, practiceRecords.wrongAnswers);
        }
        // v5: every record table gained a `uuid` sync id. answer_records and
        // sub_category_records have existed in every prior version; practice_records
        // only needs the column when it existed WITHOUT uuid (from >= 3).
        if (from < 5) {
          await m.addColumn(answerRecords, answerRecords.uuid);
          await m.addColumn(subCategoryRecords, subCategoryRecords.uuid);
          if (from >= 3) {
            await m.addColumn(practiceRecords, practiceRecords.uuid);
          }
          await customStatement('UPDATE answer_records SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL');
          await customStatement('UPDATE sub_category_records SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL');
          await customStatement('UPDATE practice_records SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL');
        }
        // v6: sub_category_records gained `occurred_at` — when the quiz was
        // finished. Existing rows keep NULL: nothing on the device records when
        // they happened, and guessing a time would make the group feed lie.
        if (from < 6) {
          await m.addColumn(subCategoryRecords, subCategoryRecords.occurredAt);
        }
      },
    );
  }
}

// Cross-platform executor via drift_flutter: NativeDatabase (sqlite3 FFI) on
// mobile/desktop, WASM (sqlite3.wasm + drift_worker.js served from web/) on the
// web — the native FFI path is what broke the web build previously.
//
// The native database path is pinned to the historical `app.db` in the app
// documents directory so existing installs keep their saved progress; without
// this, drift_flutter would default to `saobracaj.sqlite` and orphan old data.
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'saobracaj',
    native: DriftNativeOptions(
      databasePath: () async {
        final dir = await getApplicationDocumentsDirectory();
        return p.join(dir.path, 'app.db');
      },
    ),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
