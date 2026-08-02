/// User actions for the question search.
sealed class QuestionSearchEvent {}

/// The search text changed. Recomputes the grouped results.
class QueryChanged extends QuestionSearchEvent {
  QueryChanged(this.query);

  final String query;
}
