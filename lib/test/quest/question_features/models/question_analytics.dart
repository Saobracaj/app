import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_analytics.freezed.dart';

/// How much a question is worth studying, relative to the average question that
/// can actually appear on the exam.
enum QuestionValueTier {
  /// Worth at least twice the average question.
  high,

  medium,

  low,

  /// Not drawn by the exam at all (the whole of category 38): its subcategory
  /// has no slot in any of the 699 sampled variants, so the probability is a
  /// structural zero, not a small number.
  none;

  static QuestionValueTier parse(String? raw) => switch (raw) {
    'high' => QuestionValueTier.high,
    'medium' => QuestionValueTier.medium,
    'low' => QuestionValueTier.low,
    _ => QuestionValueTier.none,
  };
}

/// What a phrase found in an answer option says about that option.
enum MarkerKind {
  /// Every option in the bank containing the phrase is correct.
  alwaysCorrect,

  /// Every option containing it is wrong.
  alwaysWrong,

  /// Lopsided but not absolute — always reported with the raw tally.
  mostlyCorrect,
  mostlyWrong;

  static MarkerKind? parse(String? raw) => switch (raw) {
    'alwaysCorrect' => MarkerKind.alwaysCorrect,
    'alwaysWrong' => MarkerKind.alwaysWrong,
    'mostlyCorrect' => MarkerKind.mostlyCorrect,
    'mostlyWrong' => MarkerKind.mostlyWrong,
    _ => null,
  };

  bool get favoursCorrect =>
      this == MarkerKind.alwaysCorrect || this == MarkerKind.mostlyCorrect;

  bool get isAbsolute =>
      this == MarkerKind.alwaysCorrect || this == MarkerKind.alwaysWrong;
}

/// A phrase whose presence in an answer option coincides with that option being
/// correct (or wrong) across the whole question bank, together with the tally it
/// rests on — `correct` of `options`.
@freezed
abstract class AnswerMarker with _$AnswerMarker {
  const factory AnswerMarker({
    required String phrase,
    required MarkerKind kind,
    required int options,
    required int correct,
  }) = _AnswerMarker;
}

/// One occurrence of a marker inside a specific question: which option of that
/// question carries it.
@freezed
abstract class QuestionMarkerHit with _$QuestionMarkerHit {
  const factory QuestionMarkerHit({
    required AnswerMarker marker,
    required int choiceIndex,
  }) = _QuestionMarkerHit;
}

/// Everything the offline analysis knows about one question.
@freezed
abstract class QuestionAnalytics with _$QuestionAnalytics {
  const QuestionAnalytics._();

  const factory QuestionAnalytics({
    /// Probability of the question being on a single exam.
    required double probability,
    required int points,

    /// Expected points, `probability * points` — what not knowing it costs on
    /// average per exam.
    required double value,
    required QuestionValueTier tier,

    /// [value] as a multiple of the average answerable question's value.
    required double ratio,

    /// The pool the exam draws this question from: [poolSlots] of [poolSize]
    /// questions, uniformly.
    required int poolSize,
    required int poolSlots,

    /// Times the question occurs in the 699 sampled exam variants. Reference
    /// only — the sample is far too small to estimate [probability] from.
    required int sampleHits,

    /// Markers matched by this question's options, in option order.
    @Default(<QuestionMarkerHit>[]) List<QuestionMarkerHit> markers,

    /// Options that repeat a content word from the question stem.
    @Default(<int>[]) List<int> stemEchoes,
  }) = _QuestionAnalytics;

  /// "Один раз на N экзаменов", rounded — the friendlier phrasing of
  /// [probability]. Infinite/zero probabilities are the caller's problem.
  int get oneInExams => probability > 0 ? (1 / probability).round() : 0;
}

/// Bank-wide numbers shared by every question, so the UI can say what "average"
/// means instead of quoting a bare percentage.
@freezed
abstract class AnalyticsSummary with _$AnalyticsSummary {
  const factory AnalyticsSummary({
    /// Exam variants the model was derived from and checked against.
    required int exams,
    required int examSize,
    required double examPoints,
    required int questions,

    /// Expected points of the average question that can appear.
    required double meanValue,

    /// Share of all answer options in the bank that are correct — the baseline
    /// the option heuristics are compared against.
    required double correctOptionRate,

    /// How often the single longest option of a question is the correct one,
    /// against what picking at random would give.
    required double longestOptionCorrect,
    required double longestOptionChance,

    /// Correct-answer rate of options that echo a word from the question stem,
    /// against those that do not.
    required double echoCorrectRate,
    required double noEchoCorrectRate,
  }) = _AnalyticsSummary;
}

/// Crowd difficulty of one question, from the backend.
@freezed
abstract class QuestionDifficulty with _$QuestionDifficulty {
  const QuestionDifficulty._();

  const factory QuestionDifficulty({
    required int attempts,
    required int wrongAttempts,
    required int learners,

    /// Raw share of wrong answers. Meaningless while [attempts] is small — show
    /// [difficulty] instead.
    required double wrongRate,

    /// The smoothed estimate the server returns: the raw rate pulled towards
    /// the bank-wide average in proportion to how thin the evidence is.
    required double difficulty,

    /// The bank-wide wrong-answer rate this question is compared against.
    required double baseline,
  }) = _QuestionDifficulty;

  /// Below this many answers the question's own record barely outweighs the
  /// prior, so the UI says "мало данных" rather than quoting a percentage as
  /// if it were measured.
  static const int reliableAttempts = 20;

  bool get isReliable => attempts >= reliableAttempts;

  /// Harder / easier / about average, against the bank-wide rate. The ±25%
  /// band keeps ordinary questions out of both extremes.
  bool get isHarder => difficulty > baseline * 1.25;
  bool get isEasier => difficulty < baseline * 0.75;
}
