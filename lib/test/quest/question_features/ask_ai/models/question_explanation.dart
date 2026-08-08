import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_explanation.freezed.dart';

part 'question_explanation.g.dart';

/// A pre-generated explanation of one question, in one language — the document
/// the generation pipeline publishes into `saobracaj_question_explanations`
/// and the backend serves verbatim via `questionExplanation(questionId:)`.
///
/// The markdown fields use the konspekt link schemes (`zakon?…`,
/// `question?id=…`, `konspekt?…`), so they render with `KonspektMarkdown`.
@freezed
abstract class QuestionExplanation with _$QuestionExplanation {
  const factory QuestionExplanation({
    required int questionId,
    @Default('ru') String lang,
    @Default(1) int version,
    /// One-two sentences answering "why is the correct option correct".
    @Default('') String summary,
    /// The full markdown walkthrough: the rule, the law reference, the trap.
    @Default('') String explanation,
    /// Why each wrong option is wrong — not just "it isn't right".
    @Default([]) List<ExplanationWrongChoice> wrongChoices,
    /// Where to read further: the deciding law paragraph and konspekt section.
    @Default([]) List<ExplanationSource> sources,
  }) = _QuestionExplanation;

  factory QuestionExplanation.fromJson(Map<String, dynamic> json) =>
      _$QuestionExplanationFromJson(json);
}

/// One wrong answer option and the reason it does not fit.
@freezed
abstract class ExplanationWrongChoice with _$ExplanationWrongChoice {
  const factory ExplanationWrongChoice({
    /// The option's position in the question's answer list.
    @Default(0) int index,
    /// The option's original (Serbian) text, as shown on the question.
    @Default('') String text,
    /// Markdown: why this option is wrong.
    @Default('') String why,
  }) = _ExplanationWrongChoice;

  factory ExplanationWrongChoice.fromJson(Map<String, dynamic> json) =>
      _$ExplanationWrongChoiceFromJson(json);
}

/// A source reference: `type` is `zakon` or `konspekt`, `uri` uses the
/// konspekt link schemes and opens through the shared markdown link handling.
@freezed
abstract class ExplanationSource with _$ExplanationSource {
  const factory ExplanationSource({
    @Default('') String type,
    @Default('') String title,
    @Default('') String uri,
  }) = _ExplanationSource;

  factory ExplanationSource.fromJson(Map<String, dynamic> json) =>
      _$ExplanationSourceFromJson(json);
}
