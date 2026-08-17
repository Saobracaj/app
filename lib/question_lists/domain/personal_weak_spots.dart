import '../../test/quest/question_features/models/question_analytics.dart';

/// Сколько раз пользователь отвечал на вопрос и сколько из этих ответов были
/// ошибочными — свод локальной истории ответов (`answer_records`).
typedef AnswerTally = ({int attempts, int wrong});

/// Вопросы, в которых пользователь ошибается, хотя остальным ученикам они
/// даются легко, — содержимое автосписка «личные слабые места».
///
/// Отбор гибридный: [mine] — моя история ответов с устройства, [crowd] —
/// снапшот `questionDifficulty` с бэкенда. Вопрос попадает в список, когда
///
///   * у меня по нему есть хотя бы одна ошибка, и
///   * общая доля ошибок по всем ученикам ниже средней по банку
///     ([QuestionDifficulty.baseline]), то есть вопрос объективно лёгкий.
///
/// Так отсекаются объективно трудные вопросы: «сложно всем» — это не пробел, а
/// свойство вопроса, и учить его отдельно смысла нет.
///
/// Порядок — по разрыву между моей долей ошибок и общей, сверху самый большой:
/// именно там разница между «я не знаю» и «никто не знает» максимальна. Ничьи
/// разрешаются по id, чтобы список не переставлялся между пересчётами.
///
/// Сравнение идёт с сырым [QuestionDifficulty.wrongRate], а не со сглаженным
/// `difficulty`: сглаживание тянет оценку к средней по банку и как раз стирает
/// то «вопрос лёгкий», которое здесь и проверяется.
List<int> personalWeakSpots({
  required Map<int, AnswerTally> mine,
  required Map<int, QuestionDifficulty> crowd,
}) {
  final scored = <({int questionId, double gap})>[];
  for (final entry in mine.entries) {
    final tally = entry.value;
    if (tally.attempts <= 0 || tally.wrong <= 0) continue;

    // Вопроса нет в снапшоте — на бэкенде по нему нет ни одного ответа, значит
    // сказать «остальным легко» не о чем.
    final difficulty = crowd[entry.key];
    if (difficulty == null) continue;
    if (difficulty.wrongRate >= difficulty.baseline) continue;

    final myRate = tally.wrong / tally.attempts;
    scored.add((questionId: entry.key, gap: myRate - difficulty.wrongRate));
  }

  scored.sort((a, b) {
    final byGap = b.gap.compareTo(a.gap);
    return byGap != 0 ? byGap : a.questionId.compareTo(b.questionId);
  });
  return [for (final item in scored) item.questionId];
}
