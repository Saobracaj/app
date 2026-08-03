import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/db.dart';

part 'question_attempts_state.freezed.dart';

/// Attempt history for one question, chronological (oldest first), shown on the
/// analysis tab of the question screen.
@freezed
sealed class QuestionAttemptsState with _$QuestionAttemptsState {
  const QuestionAttemptsState._();

  const factory QuestionAttemptsState({
    @Default(true) bool inProgress,
    @Default([]) List<AnswerRecord> attempts,
  }) = _QuestionAttemptsState;

  int get correctCount => attempts.where((a) => !a.isWrong).length;
}
