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

  Future<List<SubCategoryRecord>> getAllRecords() {
    return db.getAllSubcategoryRecords();
  }

  Future<int> addRecord(String subcategory, int rightAnswers, int allAnswers) async {
    final entry = SubCategoryRecordsCompanion.insert(subcategory: subcategory, rightAnswers: rightAnswers, allAnswers: allAnswers);
    return db.insertSubCategory(entry);
  }

  /// 2) Добавить запись
  Future<int> addAnswer(int questionId, bool isWrong) {
    final entry = AnswerRecordsCompanion.insert(questionId: questionId, date: DateTime.now(), isWrong: isWrong);
    return db.insertAnswer(entry);
  }

  /// 3) Получить все вопросы, у которых есть хотя бы одна ошибка
  /// Получить последние 100 уникальных questionId с isWrong=true, отсортированные по дате (новые сверху)
  Future<Set<int>> getQuestionsWhereLastAnswerWasWrong() async {
    final result =
        await db
            .customSelect(
              '''
    SELECT question_id
    FROM answer_records
    WHERE date = (
      SELECT MAX(date)
      FROM answer_records AS sub
      WHERE sub.question_id = answer_records.question_id
    )
    AND is_wrong = 1
    ''',
              readsFrom: {db.answerRecords},
            )
            .get();

    return result.map((row) => row.read<int>('question_id')).toSet();
  }
}
