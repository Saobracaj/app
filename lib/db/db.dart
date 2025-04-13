import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'answer_table.dart';

part 'db.g.dart'; // генерируется

@DriftDatabase(tables: [AnswerRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // CRUD
  Future<int> insertAnswer(AnswerRecordsCompanion entry) => into(answerRecords).insert(entry);

  Future<List<AnswerRecord>> getAllAnswers() => select(answerRecords).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase(file);
  });
}
