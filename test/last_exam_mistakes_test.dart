import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/db/answer_repository.dart';
import 'package:saobracaj/db/db.dart';

/// Источник автосписка «ошибки последнего экзамена»: `wrongAnswers` самой свежей
/// по `time` записи practice_records.
void main() {
  late AppDatabase db;
  late AnswerRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AnswerRepository(db);
  });

  tearDown(() => db.close());

  Future<void> addExam({
    required DateTime time,
    required List<int> wrongAnswers,
  }) => repository.insertPracticeRecord(
    PracticeRecordsCompanion(
      points: Value(100 - wrongAnswers.length),
      time: Value(time),
      mistakes: Value(wrongAnswers.length),
      durationSeconds: const Value(600),
      wrongAnswers: Value(wrongAnswers),
    ),
  );

  test('экзаменов не было — список пуст', () async {
    expect(await repository.getLastExamMistakes(), isEmpty);
  });

  test('берётся самая свежая попытка, а не последняя вставленная', () async {
    await addExam(time: DateTime(2026, 8, 17, 10), wrongAnswers: [4, 5]);
    // Запись более старого экзамена, добавленная позже (так приходит синхрони-
    // зация с другого устройства), выдачу менять не должна.
    await addExam(time: DateTime(2026, 8, 16, 9), wrongAnswers: [1, 2, 3]);

    expect(await repository.getLastExamMistakes(), [4, 5]);
  });

  test('порядок вопросов сохраняется как в экзамене', () async {
    await addExam(time: DateTime(2026, 8, 17, 12), wrongAnswers: [30, 12, 7]);

    expect(await repository.getLastExamMistakes(), [30, 12, 7]);
  });

  test('экзамен без ошибок даёт пустой список', () async {
    await addExam(time: DateTime(2026, 8, 17, 11), wrongAnswers: [9]);
    await addExam(time: DateTime(2026, 8, 17, 13), wrongAnswers: const []);

    expect(
      await repository.getLastExamMistakes(),
      isEmpty,
      reason: 'ошибки предыдущей попытки не должны всплывать заново',
    );
  });

  test('старая запись без wrongAnswers не ломает расчёт', () async {
    // Колонка появилась миграцией v4 — у попыток до неё её просто нет.
    await repository.insertPracticeRecord(
      PracticeRecordsCompanion(
        points: const Value(90),
        time: Value(DateTime(2026, 8, 17, 14)),
        mistakes: const Value(2),
        durationSeconds: const Value(600),
      ),
    );

    expect(await repository.getLastExamMistakes(), isEmpty);
  });
}
