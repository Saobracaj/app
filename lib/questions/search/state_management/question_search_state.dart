import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/models/models.dart';

part 'question_search_state.freezed.dart';

/// One category worth of search hits: the category name plus the matching
/// questions inside it. Categories with no matches are never emitted.
@freezed
sealed class QuestionSearchGroup with _$QuestionSearchGroup {
  const factory QuestionSearchGroup({required String categoryName, required List<Question> questions}) = _QuestionSearchGroup;
}

/// State of the question search on the questions page.
///
/// [query] is the raw text in the field; when it is blank the search is
/// inactive and the normal category list is shown instead. [groups] holds the
/// matches grouped by category, in category order.
@freezed
sealed class QuestionSearchState with _$QuestionSearchState {
  const QuestionSearchState._();

  const factory QuestionSearchState({@Default('') String query, @Default([]) List<QuestionSearchGroup> groups}) = _QuestionSearchState;

  /// Whether the user is actively searching (the field has non-whitespace text).
  bool get isActive => query.trim().isNotEmpty;
}
