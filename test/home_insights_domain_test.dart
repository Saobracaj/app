import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/db/answer_repository.dart';
import 'package:saobracaj/db/db.dart';
import 'package:saobracaj/home/domain/home_insights.dart';
import 'package:saobracaj/models/models.dart';

/// Расчёты карточек главной — чистые функции над историей ответов, банком и
/// весами вопросов из схемы экзамена.

Question _q(int id, {String category = '25', int subcategory = 91}) => Question(
  id: id,
  imageId: id,
  text: 'Q$id',
  choicesReq: 1,
  hasImage: false,
  points: 1,
  choices: const [Choice(text: 'a', isCorrect: true)],
  categoryId: category,
  subcategoryId: subcategory,
);

final _categories = [
  const Category(
    id: '25',
    name: 'Основе',
    subcategories: [
      Subcategory(id: 91, description: 'Одредбе'),
      Subcategory(id: 93, description: 'Незгоде'),
    ],
  ),
  const Category(
    id: '30',
    name: 'Правила',
    subcategories: [Subcategory(id: 120, description: 'Раскрснице')],
  ),
];

final _questions = [
  for (var i = 1; i <= 6; i++) _q(i),
  for (var i = 7; i <= 8; i++) _q(i, subcategory: 93),
  for (var i = 9; i <= 12; i++) _q(i, category: '30', subcategory: 120),
];

DayActivity _day(DateTime day, int answers, {int wrong = 0}) =>
    DayActivity(day: day, answers: answers, wrong: wrong);

PracticeRecord _exam(int points, DateTime time, {int mistakes = 0}) =>
    PracticeRecord(
      points: points,
      time: time,
      mistakes: mistakes,
      durationSeconds: 600,
      wrongAnswers: const [],
      uuid: null,
    );

void main() {
  group('готовность', () {
    test(
      'доля = вес известных вопросов / вес всех, ненаправляемые не в счёт',
      () {
        // Вопрос 1 «стоит» втрое больше остальных; 12 экзамен не выносит.
        final weights = {
          for (final q in _questions) q.id: q.id == 1 ? 3.0 : 1.0,
          12: 0.0,
        };
        final readiness = computeReadiness(
          questions: _questions,
          lastAnswers: {1: false, 2: false, 3: true, 9: false},
          weights: weights,
        );
        // Всего 3 + 10 = 13; известно 3 + 1 + 1 = 5.
        expect(readiness.share, closeTo(5 / 13, 1e-9));
        expect(readiness.percent, 38);
        expect(readiness.known, 3);
        expect(readiness.answered, 4);
        expect(readiness.total, 11);
      },
    );

    test('слабая тема — та, где теряется больше всего баллов', () {
      final weights = {for (final q in _questions) q.id: 1.0};
      final readiness = computeReadiness(
        questions: _questions,
        lastAnswers: {for (var i = 1; i <= 6; i++) i: false, 9: true},
        weights: weights,
      );
      // 91 закрыта целиком, 93 теряет 2, 120 — 4.
      expect(readiness.weakestSubcategoryId, 120);
    });

    test('без ответов слабой темы нет', () {
      final readiness = computeReadiness(
        questions: _questions,
        lastAnswers: const {},
        weights: {for (final q in _questions) q.id: 1.0},
      );
      expect(readiness.share, 0);
      expect(readiness.weakestSubcategoryId, isNull);
    });
  });

  group('симуляции', () {
    test('нет попыток — нет графика', () {
      expect(computeExamTrend(const []), isNull);
    });

    test('последние попытки по времени, сдано из последних пяти', () {
      final base = DateTime(2026, 9, 1);
      final records = [
        for (var i = 0; i < 20; i++)
          _exam(i < 15 ? 60 : 90, base.add(Duration(days: i))),
      ];
      // Перемешанный порядок на входе.
      records.shuffle();
      final trend = computeExamTrend(records)!;
      expect(trend.attempts.length, 15);
      expect(trend.attempts.first.time, base.add(const Duration(days: 5)));
      expect(trend.attempts.last.time, base.add(const Duration(days: 19)));
      expect(trend.recentWindow, 5);
      expect(trend.passedOfRecent, 5);
      expect(trend.attempts.first.passed, isFalse);
      expect(trend.attempts.last.passed, isTrue);
    });

    test('попытки ниже порога статистики на графике не показываются', () {
      // «Полистали и бросили»: 2 верных из 41, остальное — ошибки
      // (неотвеченные тоже). Такая запись могла остаться с версий до порога.
      final skimmed = _exam(4, DateTime(2026, 9, 3), mistakes: 39);
      final trend = computeExamTrend([
        _exam(90, DateTime(2026, 9, 1)),
        skimmed,
        _exam(60, DateTime(2026, 9, 2), mistakes: 31),
      ])!;
      expect(trend.attempts.map((a) => a.points), [90, 60]);
      expect(trend.recentWindow, 2);
      expect(trend.passedOfRecent, 1);
    });

    test('одни попытки ниже порога — графика нет', () {
      expect(
        computeExamTrend([_exam(0, DateTime(2026, 9, 1), mistakes: 41)]),
        isNull,
      );
    });

    test('85 баллов — сдано, 84 — нет', () {
      expect(_exam(85, DateTime(2026)).points >= 85, isTrue);
      final trend = computeExamTrend([
        _exam(84, DateTime(2026, 9, 1)),
        _exam(85, DateTime(2026, 9, 2)),
      ])!;
      expect(trend.attempts.map((a) => a.passed), [false, true]);
      expect(trend.passedOfRecent, 1);
      expect(trend.recentWindow, 2);
    });
  });

  group('активность', () {
    final today = DateTime(2026, 9, 28, 15, 30);

    test('серия считается назад от сегодня', () {
      final activity = computeActivity(
        days: [
          _day(DateTime(2026, 9, 26), 10),
          _day(DateTime(2026, 9, 27), 40),
          _day(DateTime(2026, 9, 28), 5),
        ],
        now: today,
        dailyGoal: 30,
      );
      expect(activity.streak, 3);
      expect(activity.todayAnswers, 5);
      expect(activity.goalReached, isFalse);
    });

    test('сегодня ещё пусто — серия жива со вчера', () {
      final activity = computeActivity(
        days: [
          _day(DateTime(2026, 9, 26), 10),
          _day(DateTime(2026, 9, 27), 40),
        ],
        now: today,
        dailyGoal: 30,
      );
      expect(activity.streak, 2);
      expect(activity.todayAnswers, 0);
    });

    test('пропущенный день рвёт серию', () {
      final activity = computeActivity(
        days: [
          _day(DateTime(2026, 9, 20), 10),
          _day(DateTime(2026, 9, 26), 40),
        ],
        now: today,
        dailyGoal: 30,
      );
      expect(activity.streak, 0);
    });

    test('цель выполнена', () {
      final activity = computeActivity(
        days: [_day(DateTime(2026, 9, 28), 30)],
        now: today,
        dailyGoal: 30,
      );
      expect(activity.goalReached, isTrue);
      expect(activity.streak, 1);
    });
  });

  group('слабые темы', () {
    test('порог по числу ответов, худшие первыми, без безошибочных', () {
      final topics = computeWeakTopics(
        questions: _questions,
        categories: _categories,
        lastAnswers: {
          // 91: 6 ответов, 2 ошибки → 67 %.
          1: false, 2: false, 3: false, 4: false, 5: true, 6: true,
          // 93: 2 ответа — мало.
          7: true, 8: true,
          // 120: 4 ответа, но порог 3 в тесте → 25 %.
          9: true, 10: true, 11: true, 12: false,
        },
        minAnswered: 3,
      );
      expect(topics.map((t) => t.subcategoryId), [120, 91]);
      expect(topics.first.title, 'Раскрснице');
      expect(topics.first.categoryId, '30');
      expect(topics.first.accuracy, 0.25);
      expect(topics.first.questionIds, [9, 10, 11, 12]);
      expect(topics.last.correct, 4);
      expect(topics.last.answered, 6);
    });

    test('тема без ошибок слабой не бывает', () {
      final topics = computeWeakTopics(
        questions: _questions,
        categories: _categories,
        lastAnswers: {for (var i = 1; i <= 6; i++) i: false},
      );
      expect(topics, isEmpty);
    });

    test('не больше limit', () {
      final topics = computeWeakTopics(
        questions: _questions,
        categories: _categories,
        lastAnswers: {for (final q in _questions) q.id: true},
        minAnswered: 1,
        limit: 2,
      );
      expect(topics.length, 2);
    });
  });

  group('покрытие', () {
    test('по категориям в порядке каталога', () {
      final coverage = computeCoverage(
        questions: _questions,
        categories: _categories,
        lastAnswers: {1: false, 2: true, 9: false},
      );
      expect(coverage.map((c) => c.categoryId), ['25', '30']);
      final osnove = coverage.first;
      expect(osnove.name, 'Основе');
      expect(osnove.total, 8);
      expect(osnove.answered, 2);
      expect(osnove.correct, 1);
      expect(osnove.unansweredIds, [3, 4, 5, 6, 7, 8]);
      expect(osnove.coverage, 0.25);
      expect(osnove.accuracy, 0.5);
    });

    test('категория без вопросов пропускается', () {
      final coverage = computeCoverage(
        questions: [_q(1)],
        categories: _categories,
        lastAnswers: const {},
      );
      expect(coverage.length, 1);
    });
  });

  group('отсчёт до экзамена', () {
    final now = DateTime(2026, 9, 28, 10);

    test('дни и прогноз по темпу за две недели', () {
      final countdown = computeCountdown(
        examDate: DateTime(2026, 10, 8),
        now: now,
        // 14 дней × 10 ответов, плюс старый день вне окна.
        days: [
          _day(DateTime(2026, 9, 1), 500),
          for (var i = 0; i < 14; i++)
            _day(DateTime(2026, 9, 15).add(Duration(days: i)), 10),
        ],
        answeredDistinct: 100,
        total: 1000,
      );
      expect(countdown.daysLeft, 10);
      expect(countdown.pace, 10);
      // 100 + 10 × 10 = 200 из 1000.
      expect(countdown.projectedPercent, 20);
    });

    test('прогноз не выше 100 % и только при темпе', () {
      final full = computeCountdown(
        examDate: DateTime(2026, 12, 1),
        now: now,
        days: [_day(DateTime(2026, 9, 28), 1400)],
        answeredDistinct: 0,
        total: 100,
      );
      expect(full.projectedPercent, 100);
      final idle = computeCountdown(
        examDate: DateTime(2026, 12, 1),
        now: now,
        days: const [],
        answeredDistinct: 10,
        total: 100,
      );
      expect(idle.projectedPercent, isNull);
    });

    test('сегодня и прошедшая дата', () {
      expect(
        computeCountdown(
          examDate: DateTime(2026, 9, 28, 23),
          now: now,
          days: const [],
          answeredDistinct: 0,
          total: 1,
        ).daysLeft,
        0,
      );
      expect(
        computeCountdown(
          examDate: DateTime(2026, 9, 20),
          now: now,
          days: const [],
          answeredDistinct: 0,
          total: 1,
        ).daysLeft,
        -8,
      );
    });
  });

  group('сводка', () {
    test('всего, точность за неделю, симуляции', () {
      final summary = computeSummary(
        days: [
          _day(DateTime(2026, 9, 1), 100, wrong: 50),
          _day(DateTime(2026, 9, 22), 10, wrong: 5),
          _day(DateTime(2026, 9, 28), 10, wrong: 0),
        ],
        records: [
          _exam(90, DateTime(2026, 9, 2)),
          _exam(70, DateTime(2026, 9, 3)),
        ],
        now: DateTime(2026, 9, 28, 12),
      );
      expect(summary.totalAnswers, 120);
      // Окно — 7 дней: 22.09 попадает, 01.09 нет.
      expect(summary.weekAccuracy, closeTo(15 / 20, 1e-9));
      expect(summary.simulations, 2);
      expect(summary.simulationSeconds, 1200);
    });

    test('симуляции ниже порога не считаются ни штукой, ни временем', () {
      final summary = computeSummary(
        days: const [],
        records: [
          _exam(90, DateTime(2026, 9, 2)),
          _exam(0, DateTime(2026, 9, 3), mistakes: 41),
        ],
        now: DateTime(2026, 9, 28, 12),
      );
      expect(summary.simulations, 1);
      expect(summary.simulationSeconds, 600);
    });

    test('без ответов за неделю точности нет', () {
      final summary = computeSummary(
        days: const [],
        records: const [],
        now: DateTime(2026, 9, 28),
      );
      expect(summary.weekAccuracy, isNull);
    });
  });

  group('вопрос дня', () {
    test('в один день один и тот же, в разные — разные', () {
      final a = pickDailyQuestion(_questions, DateTime(2026, 9, 28, 8));
      final b = pickDailyQuestion(_questions, DateTime(2026, 9, 28, 23));
      expect(a, same(b));
      final picks = {
        for (var i = 0; i < 12; i++)
          pickDailyQuestion(_questions, DateTime(2026, 9, 1 + i))!.id,
      };
      expect(picks.length, greaterThan(3), reason: 'дни разбросаны по банку');
    });

    test('пустой банк — null', () {
      expect(pickDailyQuestion(const [], DateTime(2026)), isNull);
    });
  });

  group('репозиторий', () {
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
            date: Value(at ?? DateTime(2026, 9, 28, 12)),
            isWrong: Value(wrong),
          ),
        );

    test('последний ответ на вопрос — по порядку записи', () async {
      await answer(1, wrong: true, at: DateTime(2026, 9, 1));
      await answer(1, wrong: false, at: DateTime(2026, 9, 2));
      await answer(2, wrong: false, at: DateTime(2026, 9, 1));
      await answer(2, wrong: true, at: DateTime(2026, 9, 3));
      await answer(3, wrong: false);

      expect(await repository.getLastAnswers(), {1: false, 2: true, 3: false});
    });

    test('сводка по дням', () async {
      await answer(1, wrong: true, at: DateTime(2026, 9, 27, 9));
      await answer(2, wrong: false, at: DateTime(2026, 9, 27, 23, 59));
      await answer(3, wrong: false, at: DateTime(2026, 9, 28, 0, 1));

      final days = await repository.getDailyActivity();
      expect(days.map((d) => d.day), [
        DateTime(2026, 9, 27),
        DateTime(2026, 9, 28),
      ]);
      expect(days.first.answers, 2);
      expect(days.first.wrong, 1);
      expect(days.first.correct, 1);
      expect(days.last.answers, 1);
    });

    test('поток изменений срабатывает на запись', () async {
      final seen = <void>[];
      final sub = repository.changes.listen(seen.add);
      await answer(1, wrong: false);
      await Future<void>.delayed(Duration.zero);
      expect(seen, isNotEmpty);
      await sub.cancel();
    });
  });
}
