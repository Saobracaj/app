import 'package:drift/drift.dart';

import 'db.dart';

class AnswerRepository {
  final AppDatabase db;

  AnswerRepository(this.db);

  /// 1) Получить все записи по questionId в хронологическом порядке
  Future<List<AnswerRecord>> getAnswersByQuestionId(int questionId) {
    return (db.select(db.answerRecords)
      ..where((tbl) => tbl.questionId.equals(questionId))
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.date)]))
        .get();
  }

  /// 2) Добавить запись
  Future<int> addAnswer(int questionId, bool isWrong) {
    final entry = AnswerRecordsCompanion.insert(
      questionId: questionId,
      date: DateTime.now(),
      isWrong: isWrong,
    );
    return db.insertAnswer(entry);
  }

  /// 3) Получить все вопросы, у которых есть хотя бы одна ошибка
  Future<List<int>> getQuestionsWithErrors() async {
    final query = await (db.selectOnly(db.answerRecords)
      ..addColumns([db.answerRecords.questionId])
      ..where(db.answerRecords.isWrong.equals(true))
      ..groupBy([db.answerRecords.questionId]))
        .get();

    return query.map((row) => row.read(db.answerRecords.questionId)!).toList();
  }
}
