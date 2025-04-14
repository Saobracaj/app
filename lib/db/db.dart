import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'answer_table.dart';

part 'db.g.dart'; // генерируется

@DriftDatabase(tables: [AnswerRecords, SubCategoryRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  // CRUD
  Future<int> insertAnswer(AnswerRecordsCompanion entry) => into(answerRecords).insert(entry);

  Future<List<AnswerRecord>> getAllAnswers() => select(answerRecords).get();
  Future<List<SubCategoryRecord>> getAllSubcategoryRecords() => select(subCategoryRecords).get();
  Future<int> insertSubCategory(SubCategoryRecordsCompanion entry) => into(subCategoryRecords).insert(entry);

  /*@override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // we added the dueDate property in the change from version 1 to
          // version 2
          await m.add;
        }
      },
    );
  }*/
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase(file);
  });
}
