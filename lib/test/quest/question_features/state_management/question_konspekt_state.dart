import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';

part 'question_konspekt_state.freezed.dart';

@freezed
sealed class QuestionKonspektState with _$QuestionKonspektState {
  const factory QuestionKonspektState({
    @Default(true) bool inProgress,

    /// The konspekt sections that reference this question, in document order.
    @Default([]) List<KonspektSection> sections,
  }) = _QuestionKonspektState;
}
