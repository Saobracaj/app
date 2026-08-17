import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/db/answer_repository.dart';
import 'package:saobracaj/db/db.dart';

/// Источник автосписка «хронические ошибки»: вопросы, в которых пользователь
/// ошибался не меньше двух раз за всё время, независимо от последнего ответа.
void main() {
  late AppDatabase db;
  late AnswerRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AnswerRepository(db);
  });

  tearDown(() => db.close());

  Future<void> answer(int questionId, {required bool wrong, DateTime? at}) =>
      db.insertAnswer(
        AnswerRecordsCompanion(
          questionId: Value(questionId),
          date: Value(at ?? DateTime(2026, 8, 17, 12)),
          isWrong: Value(wrong),
        ),
      );

  test('истории нет — список пуст', () async {
    expect(await repository.getChronicMistakes(), isEmpty);
  });

  test('одной ошибки мало, двух достаточно', () async {
    await answer(1, wrong: true, at: DateTime(2026, 8, 10));
    await answer(2, wrong: true, at: DateTime(2026, 8, 10));
    await answer(2, wrong: true, at: DateTime(2026, 8, 11));

    expect(await repository.getChronicMistakes(), [2]);
  });

  test('верный последний ответ вопрос из списка не убирает', () async {
    await answer(5, wrong: true, at: DateTime(2026, 8, 10));
    await answer(5, wrong: true, at: DateTime(2026, 8, 11));
    // Один угаданный ответ выкидывает вопрос из «последних ошибок», хотя он ещё
    // не выучен, — ради этого случая список и заведён.
    await answer(5, wrong: false, at: DateTime(2026, 8, 12));

    expect(await repository.getChronicMistakes(), [5]);
    expect(
      await repository.getQuestionsWhereLastAnswerWasWrong(),
      isEmpty,
      reason: '«последние ошибки» здесь как раз пусты',
    );
  });

  test('верные ответы в счёт ошибок не идут', () async {
    await answer(7, wrong: false, at: DateTime(2026, 8, 10));
    await answer(7, wrong: false, at: DateTime(2026, 8, 11));
    await answer(7, wrong: true, at: DateTime(2026, 8, 12));

    expect(await repository.getChronicMistakes(), isEmpty);
  });

  test('сначала те, где ошибок больше', () async {
    for (var i = 0; i < 2; i++) {
      await answer(10, wrong: true, at: DateTime(2026, 8, 10 + i));
    }
    for (var i = 0; i < 4; i++) {
      await answer(11, wrong: true, at: DateTime(2026, 8, 1 + i));
    }
    for (var i = 0; i < 3; i++) {
      await answer(12, wrong: true, at: DateTime(2026, 8, 5 + i));
    }

    expect(await repository.getChronicMistakes(), [11, 12, 10]);
  });

  test('при равном числе ошибок свежие выше', () async {
    await answer(20, wrong: true, at: DateTime(2026, 8, 1));
    await answer(20, wrong: true, at: DateTime(2026, 8, 2));
    await answer(21, wrong: true, at: DateTime(2026, 8, 3));
    await answer(21, wrong: true, at: DateTime(2026, 8, 15));
    await answer(22, wrong: true, at: DateTime(2026, 8, 4));
    await answer(22, wrong: true, at: DateTime(2026, 8, 9));

    expect(await repository.getChronicMistakes(), [21, 22, 20]);
  });
}
