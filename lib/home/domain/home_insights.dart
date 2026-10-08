/// The figures behind the home-screen cards, computed from what the device
/// already holds: the local answer history, the bundled question bank and the
/// exam blueprint (`assets/question_analytics.json`).
///
/// Everything here is a pure function of its inputs, so the cards can be
/// tested without a database or a widget tree. `HomeInsightsBloc` gathers the
/// inputs and calls these.
library;

import '../../db/answer_repository.dart' show DayActivity;
import '../../db/db.dart' show PracticeRecord;
import '../../models/models.dart';
import '../../test/practice/finalize_practice.dart' show kMinPoints;
import '../../test/practice/state_management/practice_bloc.dart'
    show practiceRecordCounted;

/// How ready the user is for the exam.
///
/// [share] is the fraction of the *expected exam points* covered by questions
/// whose last answer was right: each question weighs `probability × points`
/// (what it brings to an average exam), so a question drawn on every third
/// exam counts for more than one from a pool of two hundred. The pass mark is
/// 85 of 100 points, so a share around 0.85 means "about a pass".
class ReadinessInsight {
  const ReadinessInsight({
    required this.share,
    required this.known,
    required this.answered,
    required this.total,
    this.weakestSubcategoryId,
  });

  /// 0…1, see the class comment.
  final double share;

  /// Questions whose last answer was right.
  final int known;

  /// Questions answered at least once.
  final int answered;

  /// Questions in the bank the exam can draw from.
  final int total;

  /// The subcategory losing the most exam points right now (unanswered and
  /// wrong questions alike), or `null` when nothing was answered yet.
  final int? weakestSubcategoryId;

  int get percent => (share * 100).round();
}

/// One finished exam simulation.
class ExamAttempt {
  const ExamAttempt({
    required this.points,
    required this.mistakes,
    required this.time,
  });

  final int points;
  final int mistakes;
  final DateTime time;

  bool get passed => points >= kMinPoints;
}

/// The last simulations, oldest first, plus the pass count over the recent
/// window shown in the caption («сдано 4 из последних 5»).
class ExamTrendInsight {
  const ExamTrendInsight({
    required this.attempts,
    required this.passedOfRecent,
    required this.recentWindow,
  });

  final List<ExamAttempt> attempts;
  final int passedOfRecent;
  final int recentWindow;

  ExamAttempt get last => attempts.last;
}

/// Study activity by day, the current streak and today's progress toward
/// the daily goal.
class ActivityInsight {
  const ActivityInsight({
    required this.answersByDay,
    required this.streak,
    required this.todayAnswers,
    required this.dailyGoal,
  });

  /// Answers per local day (midnight keys); days without activity are absent.
  final Map<DateTime, int> answersByDay;

  /// Consecutive days with activity ending today or yesterday (a streak is
  /// not lost until a whole day passes without a single answer).
  final int streak;

  final int todayAnswers;
  final int dailyGoal;

  bool get goalReached => todayAnswers >= dailyGoal;
}

/// A subcategory with its current accuracy — the last answer per question.
class TopicInsight {
  const TopicInsight({
    required this.subcategoryId,
    required this.categoryId,
    required this.title,
    required this.answered,
    required this.correct,
    required this.questionIds,
  });

  final int subcategoryId;
  final String categoryId;

  /// The subcategory description from `categories.json` (Serbian, as
  /// everywhere in the app).
  final String title;

  final int answered;
  final int correct;

  /// Every question of the subcategory — what the «прогнать» button runs.
  final List<int> questionIds;

  double get accuracy => answered == 0 ? 0 : correct / answered;
}

/// How much of a category the user has been through.
class CategoryCoverageInsight {
  const CategoryCoverageInsight({
    required this.categoryId,
    required this.name,
    required this.total,
    required this.answered,
    required this.correct,
    required this.unansweredIds,
  });

  final String categoryId;
  final String name;
  final int total;

  /// Questions answered at least once.
  final int answered;

  /// Questions whose last answer was right.
  final int correct;

  /// Questions never answered — what a tap on the tile runs. Empty once the
  /// category is fully covered; the tile then runs the whole category.
  final List<int> unansweredIds;

  double get coverage => total == 0 ? 0 : answered / total;
  double get accuracy => answered == 0 ? 0 : correct / answered;
}

/// Days left to the exam and what the current pace promises.
class ExamCountdownInsight {
  const ExamCountdownInsight({
    required this.examDate,
    required this.daysLeft,
    required this.pace,
    required this.projectedPercent,
  });

  final DateTime examDate;

  /// Whole days from today to the exam; negative once it has passed.
  final int daysLeft;

  /// Answers per day over the last [paceWindowDays] days.
  final double pace;

  /// The share of the bank the user will have touched by the exam if the pace
  /// holds, in percent; `null` while there is no pace to extrapolate.
  final int? projectedPercent;

  static const paceWindowDays = 14;
}

/// The headline figures of the summary tiles.
class SummaryInsight {
  const SummaryInsight({
    required this.totalAnswers,
    required this.weekAccuracy,
    required this.simulations,
    required this.simulationSeconds,
  });

  final int totalAnswers;

  /// Share of right answers over the last seven days, or `null` without any.
  final double? weekAccuracy;

  final int simulations;
  final int simulationSeconds;
}

/// The konspekt the user opened last.
class LastKonspektInsight {
  const LastKonspektInsight({required this.categoryId, required this.name});

  final String categoryId;
  final String name;
}

/// Midnight of [moment]'s local day.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// See [ReadinessInsight]. [weights] is the exam value of every question the
/// exam can draw (`QuestionAnalyticsRepository.weights`); [lastAnswers] maps
/// a question to whether its *last* answer was wrong.
ReadinessInsight computeReadiness({
  required List<Question> questions,
  required Map<int, bool> lastAnswers,
  required Map<int, double> weights,
}) {
  var total = 0.0;
  var covered = 0.0;
  var known = 0;
  var answered = 0;
  var drawable = 0;
  final lostBySubcategory = <int, double>{};
  for (final question in questions) {
    final weight = weights[question.id] ?? 0;
    if (weight <= 0) continue;
    drawable++;
    total += weight;
    final wrong = lastAnswers[question.id];
    if (wrong != null) answered++;
    if (wrong == false) {
      covered += weight;
      known++;
    } else {
      lostBySubcategory.update(
        question.subcategoryId,
        (v) => v + weight,
        ifAbsent: () => weight,
      );
    }
  }
  int? weakest;
  if (answered > 0) {
    var worst = 0.0;
    lostBySubcategory.forEach((id, lost) {
      if (lost > worst) {
        worst = lost;
        weakest = id;
      }
    });
  }
  return ReadinessInsight(
    share: total == 0 ? 0 : covered / total,
    known: known,
    answered: answered,
    total: drawable,
    weakestSubcategoryId: weakest,
  );
}

/// The simulations the home screen counts: those past the statistics
/// threshold (see [practiceRecordCounted]). A simulation that was opened,
/// skimmed and ended with a couple of answers is no attempt — it would hang
/// on the trend as a zero-point failure and inflate the simulation count.
List<PracticeRecord> countedPracticeRecords(List<PracticeRecord> records) =>
    records.where(practiceRecordCounted).toList();

/// See [ExamTrendInsight]. [records] in any order, filtered through
/// [countedPracticeRecords]; at most [limit] most recent attempts are kept,
/// oldest first. `null` without a single counted attempt.
ExamTrendInsight? computeExamTrend(
  List<PracticeRecord> records, {
  int limit = 15,
  int recentWindow = 5,
}) {
  final counted = countedPracticeRecords(records);
  if (counted.isEmpty) return null;
  final sorted = counted..sort((a, b) => a.time.compareTo(b.time));
  final attempts = [
    for (final r in sorted.skip(
      sorted.length > limit ? sorted.length - limit : 0,
    ))
      ExamAttempt(points: r.points, mistakes: r.mistakes, time: r.time),
  ];
  final recent = attempts.length > recentWindow
      ? attempts.sublist(attempts.length - recentWindow)
      : attempts;
  return ExamTrendInsight(
    attempts: attempts,
    passedOfRecent: recent.where((a) => a.passed).length,
    recentWindow: recent.length,
  );
}

/// See [ActivityInsight].
ActivityInsight computeActivity({
  required List<DayActivity> days,
  required DateTime now,
  required int dailyGoal,
}) {
  final byDay = {for (final d in days) dayOf(d.day): d.answers};
  final today = dayOf(now);
  final yesterday = today.subtract(const Duration(days: 1));
  var streak = 0;
  // A streak counts back from today, or from yesterday while today is still
  // empty: the day is not over, and «серия прервана» before the first answer
  // of the morning would be plain wrong.
  var cursor = byDay.containsKey(today) ? today : yesterday;
  while (byDay.containsKey(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return ActivityInsight(
    answersByDay: byDay,
    streak: streak,
    todayAnswers: byDay[today] ?? 0,
    dailyGoal: dailyGoal,
  );
}

/// See [TopicInsight]: the [limit] subcategories with the lowest accuracy
/// among those with at least [minAnswered] answered questions and at least
/// one wrong answer. Ties go to the topic with more answers — more evidence.
List<TopicInsight> computeWeakTopics({
  required List<Question> questions,
  required List<Category> categories,
  required Map<int, bool> lastAnswers,
  int minAnswered = 5,
  int limit = 3,
}) {
  final titles = <int, (String, String)>{
    for (final c in categories)
      for (final s in c.subcategories) s.id: (c.id, s.description),
  };
  final ids = <int, List<int>>{};
  final answered = <int, int>{};
  final correct = <int, int>{};
  for (final q in questions) {
    (ids[q.subcategoryId] ??= []).add(q.id);
    final wrong = lastAnswers[q.id];
    if (wrong == null) continue;
    answered.update(q.subcategoryId, (v) => v + 1, ifAbsent: () => 1);
    if (!wrong) {
      correct.update(q.subcategoryId, (v) => v + 1, ifAbsent: () => 1);
    }
  }
  final topics = <TopicInsight>[];
  for (final entry in answered.entries) {
    if (entry.value < minAnswered) continue;
    final right = correct[entry.key] ?? 0;
    if (right >= entry.value) continue;
    final title = titles[entry.key];
    topics.add(
      TopicInsight(
        subcategoryId: entry.key,
        categoryId: title?.$1 ?? '',
        title: title?.$2 ?? '${entry.key}',
        answered: entry.value,
        correct: right,
        questionIds: ids[entry.key] ?? const [],
      ),
    );
  }
  topics.sort((a, b) {
    final byAccuracy = a.accuracy.compareTo(b.accuracy);
    if (byAccuracy != 0) return byAccuracy;
    return b.answered.compareTo(a.answered);
  });
  return topics.take(limit).toList();
}

/// See [CategoryCoverageInsight], in the order of `categories.json`;
/// categories without questions are left out.
List<CategoryCoverageInsight> computeCoverage({
  required List<Question> questions,
  required List<Category> categories,
  required Map<int, bool> lastAnswers,
}) {
  final byCategory = <String, List<Question>>{};
  for (final q in questions) {
    (byCategory[q.categoryId] ??= []).add(q);
  }
  return [
    for (final c in categories)
      if (byCategory[c.id] case final list? when list.isNotEmpty)
        CategoryCoverageInsight(
          categoryId: c.id,
          name: c.name,
          total: list.length,
          answered: list.where((q) => lastAnswers.containsKey(q.id)).length,
          correct: list.where((q) => lastAnswers[q.id] == false).length,
          unansweredIds: [
            for (final q in list)
              if (!lastAnswers.containsKey(q.id)) q.id,
          ],
        ),
  ];
}

/// See [ExamCountdownInsight]. [answeredDistinct] and [total] size the bank
/// coverage the pace is extrapolated over.
ExamCountdownInsight computeCountdown({
  required DateTime examDate,
  required DateTime now,
  required List<DayActivity> days,
  required int answeredDistinct,
  required int total,
}) {
  final today = dayOf(now);
  final daysLeft = dayOf(examDate).difference(today).inDays;
  final windowStart = today.subtract(
    const Duration(days: ExamCountdownInsight.paceWindowDays - 1),
  );
  var recent = 0;
  for (final d in days) {
    if (!dayOf(d.day).isBefore(windowStart)) recent += d.answers;
  }
  final pace = recent / ExamCountdownInsight.paceWindowDays;
  int? projected;
  if (pace > 0 && total > 0 && daysLeft >= 0) {
    final reach = answeredDistinct + pace * daysLeft;
    projected = (reach.clamp(0, total) / total * 100).round();
  }
  return ExamCountdownInsight(
    examDate: examDate,
    daysLeft: daysLeft,
    pace: pace,
    projectedPercent: projected,
  );
}

/// See [SummaryInsight]. [records] are filtered through
/// [countedPracticeRecords], so the simulation count and time agree with the
/// attempts on the trend card.
SummaryInsight computeSummary({
  required List<DayActivity> days,
  required List<PracticeRecord> records,
  required DateTime now,
}) {
  final weekStart = dayOf(now).subtract(const Duration(days: 6));
  var total = 0;
  var weekAnswers = 0;
  var weekCorrect = 0;
  for (final d in days) {
    total += d.answers;
    if (!dayOf(d.day).isBefore(weekStart)) {
      weekAnswers += d.answers;
      weekCorrect += d.correct;
    }
  }
  final counted = countedPracticeRecords(records);
  var seconds = 0;
  for (final r in counted) {
    seconds += r.durationSeconds;
  }
  return SummaryInsight(
    totalAnswers: total,
    weekAccuracy: weekAnswers == 0 ? null : weekCorrect / weekAnswers,
    simulations: counted.length,
    simulationSeconds: seconds,
  );
}

/// The question of the day: the same one for everybody on a given day, drawn
/// from [questions] by the day number so it does not walk the bank in id
/// order. `null` for an empty bank.
Question? pickDailyQuestion(List<Question> questions, DateTime now) {
  if (questions.isEmpty) return null;
  return questions[_dailyIndex(now, questions.length)];
}

/// Index of the day's pick among [count] items — a fixed-seed shuffle would be
/// heavier for the same purpose. A linear congruential step scatters
/// consecutive days across the whole range.
int _dailyIndex(DateTime now, int count) {
  final day = dayOf(now).difference(DateTime(2026)).inDays;
  // Knuth's multiplicative hash on the day number, folded into the range.
  final hashed = (day * 2654435761) & 0x7fffffff;
  return hashed % count;
}

/// Day number helper shared with the sign of the day.
int dailyPick(DateTime now, int count) => _dailyIndex(now, count);
