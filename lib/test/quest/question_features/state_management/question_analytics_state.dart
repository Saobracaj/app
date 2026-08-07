import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/question_analytics.dart';

part 'question_analytics_state.freezed.dart';

/// The analysis tab's data: the offline analytics (always available) plus the
/// crowd difficulty (needs the backend and a session, so it arrives later —
/// or not at all).
@freezed
abstract class QuestionAnalyticsState with _$QuestionAnalyticsState {
  const QuestionAnalyticsState._();

  const factory QuestionAnalyticsState({
    @Default(true) bool inProgress,

    /// Null once loaded means the question is absent from the analytics asset —
    /// a question added after it was last built.
    QuestionAnalytics? analytics,
    AnalyticsSummary? summary,

    /// Null while [difficultyInProgress] is true, or when the question has no
    /// recorded answers, the caller is a guest, or the request failed — the
    /// three are told apart by [difficultyRequiresSignIn] and
    /// [difficultyFailed], because "nobody has answered this yet" and "we could
    /// not ask" are different things to put on screen.
    QuestionDifficulty? difficulty,
    @Default(true) bool difficultyInProgress,
    @Default(false) bool difficultyRequiresSignIn,
    @Default(false) bool difficultyFailed,
  }) = _QuestionAnalyticsState;

  /// Whether there is anything to render at all.
  bool get hasAnalytics => analytics != null && summary != null;
}
