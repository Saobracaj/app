import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/models/question_explanation.dart';

part 'ask_ai_state.freezed.dart';

/// State of the "Спросить AI" tab's static explanation.
///
/// Three terminal shapes: the loaded [explanation], a `null` explanation once
/// loading finished (the question has none yet — shown as a stub, not a blank),
/// and [failed] (offline, no entitlement, server error — shown with a retry).
@freezed
abstract class AskAiState with _$AskAiState {
  const factory AskAiState({
    @Default(true) bool inProgress,
    @Default(false) bool failed,
    QuestionExplanation? explanation,
  }) = _AskAiState;
}
