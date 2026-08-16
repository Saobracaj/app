import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/markdown/phrase_highlight.dart';

part 'question_analytics.freezed.dart';

/// How much a question is worth studying, relative to the average question that
/// can actually appear on the exam. The same scale grades the bare chance of
/// being drawn ([QuestionAnalytics.probabilityTier]).
enum QuestionValueTier {
  /// Worth at least twice the average question.
  high,

  /// Between half and twice the average.
  medium,

  /// Below half the average.
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

/// What a cue found in an answer option says about that option. Only absolute
/// cues are recorded — a learner memorises a rule, not a tendency.
enum MarkerKind {
  /// Every option in the bank containing the phrase is correct.
  alwaysCorrect,

  /// Every option containing it is wrong.
  alwaysWrong;

  static MarkerKind? parse(String? raw) => switch (raw) {
    'alwaysCorrect' => MarkerKind.alwaysCorrect,
    'alwaysWrong' => MarkerKind.alwaysWrong,
    _ => null,
  };

  bool get favoursCorrect => this == MarkerKind.alwaysCorrect;
}

/// A cue whose presence in an answer option coincides with that option being
/// correct (or wrong) in every question of the bank where it occurs, together
/// with the tally it rests on — `correct` of `options`.
///
/// [whole] means the cue is the entire answer text ("Униформисани полицијски
/// службеници" is an answer in four questions and correct in all four), as
/// opposed to a phrase inside a longer answer.
@freezed
abstract class AnswerMarker with _$AnswerMarker {
  const factory AnswerMarker({
    required String phrase,
    required MarkerKind kind,
    required int options,
    required int correct,
    @Default(false) bool whole,
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

/// A "phrase in the question → the correct answer" rule: in every one of
/// [questions] questions of the bank whose text contains [stem] and which
/// offers [answer], that answer is the correct one — although [answer] on its
/// own is wrong elsewhere in the bank.
@freezed
abstract class AnswerLink with _$AnswerLink {
  const factory AnswerLink({
    required String stem,
    required String answer,
    required int questions,
  }) = _AnswerLink;
}

/// One occurrence of a link inside a specific question: which option is the
/// answer the rule points at.
@freezed
abstract class QuestionLinkHit with _$QuestionLinkHit {
  const factory QuestionLinkHit({
    required AnswerLink link,
    required int choiceIndex,
  }) = _QuestionLinkHit;
}

/// One key-phrase cue as it is shown to the learner: a marker (a phrase or a
/// whole answer that is always correct / always wrong) or a
/// question→answer link. Options are shuffled on screen, so a cue never
/// refers to "option N" — it quotes the wording, and [highlight] is what to
/// light up in the answer cards (or, for a link's stem, in the question text).
sealed class QuestionCue {
  const QuestionCue();

  /// What this cue says about the option it sits in — a link always points at
  /// the correct answer.
  bool get favoursCorrect;
}

class MarkerCue extends QuestionCue {
  const MarkerCue(this.marker);

  final AnswerMarker marker;

  @override
  bool get favoursCorrect => marker.kind.favoursCorrect;

  PhraseHighlight get highlight =>
      PhraseHighlight(marker.phrase, whole: marker.whole);
}

class LinkCue extends QuestionCue {
  const LinkCue(this.link);

  final AnswerLink link;

  @override
  bool get favoursCorrect => true;

  /// The word in the question that triggers the rule.
  PhraseHighlight get stemHighlight => PhraseHighlight(link.stem);

  /// The whole answer the rule points at.
  PhraseHighlight get answerHighlight =>
      PhraseHighlight(link.answer, whole: true);
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

    /// Question→answer links that hold for this question, in option order.
    @Default(<QuestionLinkHit>[]) List<QuestionLinkHit> links,
  }) = _QuestionAnalytics;

  /// Whether the keyword block has anything to say.
  bool get hasCues => markers.isNotEmpty || links.isNotEmpty;

  /// At most this many marker cues are shown per option: whole-answer cues
  /// first, then the best-evidenced phrase. Links are rare enough to always
  /// show.
  static const int maxMarkersPerOption = 2;

  /// The cues to show and highlight, in option order (the option order of the
  /// bank — on screen the options may be shuffled, which is why a cue quotes
  /// its wording rather than an option number).
  List<QuestionCue> get cues {
    final byOption = <int, List<AnswerMarker>>{};
    for (final hit in markers) {
      (byOption[hit.choiceIndex] ??= []).add(hit.marker);
    }
    final linksByOption = <int, List<AnswerLink>>{};
    for (final hit in links) {
      (linksByOption[hit.choiceIndex] ??= []).add(hit.link);
    }
    final options = {...byOption.keys, ...linksByOption.keys}.toList()..sort();
    return [
      for (final option in options) ...[
        for (final marker in _ranked(
          byOption[option],
        ).take(maxMarkersPerOption))
          MarkerCue(marker),
        for (final link in linksByOption[option] ?? const <AnswerLink>[])
          LinkCue(link),
      ],
    ];
  }

  /// Whole-answer cues first, then by how much evidence the phrase carries.
  static List<AnswerMarker> _ranked(List<AnswerMarker>? markers) =>
      [...?markers]..sort(
        (a, b) => a.whole != b.whole
            ? (a.whole ? -1 : 1)
            : b.options.compareTo(a.options),
      );

  /// Words to light up in the question text: the stems of the links.
  List<PhraseHighlight> get questionHighlights => [
    for (final cue in cues)
      if (cue is LinkCue) cue.stemHighlight,
  ];

  /// Phrases and whole answers to light up in the answer cards.
  List<PhraseHighlight> get optionHighlights => [
    for (final cue in cues)
      switch (cue) {
        MarkerCue() => cue.highlight,
        LinkCue() => cue.answerHighlight,
      },
  ];

  /// "Один раз на N экзаменов", rounded — the friendlier phrasing of
  /// [probability]. Infinite/zero probabilities are the caller's problem.
  int get oneInExams => probability > 0 ? (1 / probability).round() : 0;

  /// [probability] graded against the average answerable question, at the
  /// same 2× / ½× cuts as [tier] — a percentage alone does not tell a learner
  /// whether 2.6% is a lot for one question out of 1700.
  QuestionValueTier probabilityTier(AnalyticsSummary summary) {
    if (probability <= 0) return QuestionValueTier.none;
    final mean = summary.meanProbability;
    if (probability >= 2 * mean) return QuestionValueTier.high;
    if (probability >= 0.5 * mean) return QuestionValueTier.medium;
    return QuestionValueTier.low;
  }
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

    /// Probability of the average question that can appear — the yardstick
    /// for [QuestionAnalytics.probabilityTier].
    required double meanProbability,

    /// Share of all answer options in the bank that are correct — the base
    /// rate a keyword cue's record is judged against.
    required double correctOptionRate,

    /// How many questions of the bank carry at least one keyword cue.
    required int markerQuestions,
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

  /// The same three-step scale as the other two headline figures.
  QuestionValueTier get tier => isHarder
      ? QuestionValueTier.high
      : isEasier
      ? QuestionValueTier.low
      : QuestionValueTier.medium;
}
