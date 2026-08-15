import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/markdown/phrase_highlight.dart';
import '../models/question_analytics.dart';

part 'question_cues_state.freezed.dart';

/// The key-phrase cues of one question, as far as the question screen needs
/// them: what to highlight in the question text and in the answer cards once
/// the answers are revealed. Nothing until loaded; nothing for a question the
/// analytics asset does not know.
@freezed
abstract class QuestionCuesState with _$QuestionCuesState {
  const QuestionCuesState._();

  const factory QuestionCuesState({
    @Default(true) bool inProgress,
    QuestionAnalytics? analytics,
  }) = _QuestionCuesState;

  List<PhraseHighlight> get questionHighlights =>
      analytics?.questionHighlights ?? const [];

  List<PhraseHighlight> get optionHighlights =>
      analytics?.optionHighlights ?? const [];
}
