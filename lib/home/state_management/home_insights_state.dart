import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/home_insights.dart';

part 'home_insights_state.freezed.dart';

/// Everything the home-screen cards show, recomputed as one piece whenever
/// the inputs change. A `null` section means "nothing to show yet" (no
/// simulations, no exam date, no konspekt opened) and its card stays hidden
/// or shows its empty copy; [loaded] tells the first computation apart from
/// "still reading the database", so the cards do not flash empty copy at
/// start-up.
@freezed
sealed class HomeInsightsState with _$HomeInsightsState {
  const factory HomeInsightsState({
    @Default(false) bool loaded,
    ReadinessInsight? readiness,

    /// The subcategory the readiness card offers to practise — the one losing
    /// the most exam points.
    TopicInsight? weakestTopic,
    ExamTrendInsight? examTrend,
    ActivityInsight? activity,
    @Default([]) List<TopicInsight> weakTopics,
    @Default([]) List<CategoryCoverageInsight> coverage,

    /// `null` while no exam date is set.
    ExamCountdownInsight? countdown,
    SummaryInsight? summary,
    LastKonspektInsight? lastKonspekt,
  }) = _HomeInsightsState;
}
