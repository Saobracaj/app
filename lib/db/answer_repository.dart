import 'package:drift/drift.dart';

import 'db.dart';

class AnswerRepository {
  final AppDatabase db;

  AnswerRepository(this.db);

  Future<List<PracticeRecord>> getPracticeRecords() {
    return db.getPracticeRecords();
  }

  Future<int> insertPracticeRecord(PracticeRecordsCompanion entity) async {
    return await db.insertPractice(entity);
  }

  /// Вопросы, в которых пользователь ошибся в последней попытке экзамена, —
  /// содержимое автосписка «ошибки последнего экзамена».
  ///
  /// Порядок сохраняется тот же, что был в экзамене: `wrongAnswers` пишется
  /// обходом вопросов варианта (см. `PracticeBloc._onFinalizeTest`). Пустой
  /// результат означает и «экзаменов ещё не было», и «последний сдан без единой
  /// ошибки» — в обоих случаях списку нечего показывать.
  Future<List<int>> getLastExamMistakes() async {
    final last = await db.getLastPracticeRecord();
    return last?.wrongAnswers ?? const [];
  }

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

  /// 4) Вопросы, в которых пользователь ошибался не меньше двух раз за всё
  /// время, — содержимое автосписка «хронические ошибки».
  ///
  /// В отличие от «последних ошибок», последний ответ роли не играет: один
  /// угаданный ответ выкидывает вопрос из «последних ошибок», хотя он ещё не
  /// выучен. Порядок — сначала те, где ошибок больше; при равенстве выше те, где
  /// ошибались свежее.
  Future<List<int>> getChronicMistakes() async {
    final result = await db
        .customSelect(
          '''
    SELECT question_id,
           COUNT(*) AS wrong,
           MAX(date) AS last_wrong
    FROM answer_records
    WHERE is_wrong = 1
    GROUP BY question_id
    HAVING wrong >= 2
    ORDER BY wrong DESC, last_wrong DESC
    ''',
          readsFrom: {db.answerRecords},
        )
        .get();

    return result.map((row) => row.read<int>('question_id')).toList();
  }

  /// 5) Личная статистика по вопросам, в которых была хотя бы одна ошибка:
  /// сколько всего ответов и сколько из них неверных.
  ///
  /// Нужна автосписку «личные слабые места», который сравнивает мою долю ошибок
  /// с общей по всем ученикам, — там важно именно отношение, а не факт ошибки.
  Future<Map<int, ({int attempts, int wrong})>> getWrongAnswerTallies() async {
    final result = await db
        .customSelect(
          '''
    SELECT question_id,
           COUNT(*) AS attempts,
           SUM(is_wrong) AS wrong
    FROM answer_records
    GROUP BY question_id
    HAVING wrong > 0
    ''',
          readsFrom: {db.answerRecords},
        )
        .get();

    return {
      for (final row in result)
        row.read<int>('question_id'): (
          attempts: row.read<int>('attempts'),
          wrong: row.read<int>('wrong'),
        ),
    };
  }
}
