import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/models.dart';

part 'daily_question_state.freezed.dart';

@freezed
sealed class DailyQuestionState with _$DailyQuestionState {
  const DailyQuestionState._();

  const factory DailyQuestionState({
    /// Today's question; `null` until the bank is loaded.
    Question? question,

    /// Indices of the selected options.
    @Default({}) Set<int> selected,

    /// Whether the answer was checked (today, for this question).
    @Default(false) bool graded,

    /// The verdict once [graded].
    @Default(false) bool correct,
  }) = _DailyQuestionState;

  /// Indices of the right options.
  Set<int> get correctIndices => {
    for (var i = 0; i < (question?.choices.length ?? 0); i++)
      if (question!.choices[i].isCorrect) i,
  };
}
