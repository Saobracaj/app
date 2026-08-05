import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';

part 'question_konspekt_state.freezed.dart';

@freezed
sealed class QuestionKonspektState with _$QuestionKonspektState {
  const factory QuestionKonspektState({
    @Default(true) bool inProgress,

    /// The konspekt sections that reference this question, in document order.
    @Default([]) List<KonspektSection> sections,

    /// The excerpts could not be loaded (no network, no entitlement, server
    /// error). Kept apart from an empty [sections]: "this category has no
    /// notes" hides the tab, "we failed to fetch them" shows a retry instead of
    /// pretending the question has nothing to read.
    @Default(false) bool failed,
  }) = _QuestionKonspektState;
}
