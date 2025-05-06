import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'answer_table.dart';

part 'db.g.dart'; // генерируется

@DriftDatabase(tables: [AnswerRecords, SubCategoryRecords, PracticeRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  Future<int> insertAnswer(AnswerRecordsCompanion entry) => into(answerRecords).insert(entry);

  Future<int> insertPractice(PracticeRecordsCompanion entity) => into(practiceRecords).insert(entity);

  Future<List<PracticeRecord>> getPracticeRecords() {
    return (select(practiceRecords)..orderBy([(t) => OrderingTerm(expression: t.time, mode: OrderingMode.desc)])).get();
  }

  Future<List<AnswerRecord>> getAllAnswers() => select(answerRecords).get();

  Future<List<SubCategoryRecord>> getAllSubcategoryRecords() => select(subCategoryRecords).get();

  Future<int> insertSubCategory(SubCategoryRecordsCompanion entry) => into(subCategoryRecords).insert(entry);

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          await m.createTable(practiceRecords);
        }
        if (from == 3 && to == 4) {
          await customStatement('DELETE FROM practice_records WHERE duration_seconds > 2700');
          await m.addColumn(practiceRecords, practiceRecords.wrongAnswers);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase(file);
  });
}
