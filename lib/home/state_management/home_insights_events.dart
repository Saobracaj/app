import '../../models/models.dart';

sealed class HomeInsightsEvent {}

/// The question bank the figures are computed over — `null` while
/// `AllQuestionsBloc` is still loading it. Sent on start and whenever the bank
/// changes; the Bloc recomputes as soon as it has one.
class HomeInsightsQuestionsChanged extends HomeInsightsEvent {
  HomeInsightsQuestionsChanged(this.data);

  final QuestionsData? data;
}

/// The local statistics changed (an answer, a finished simulation, a sync
/// merge, a sign-out wipe) — recompute.
class HomeInsightsRefreshRequested extends HomeInsightsEvent {}

/// The user set (or removed, with `null`) the exam date.
class HomeExamDateChanged extends HomeInsightsEvent {
  HomeExamDateChanged(this.date);

  final DateTime? date;
}

/// The user picked another daily goal.
class HomeDailyGoalChanged extends HomeInsightsEvent {
  HomeDailyGoalChanged(this.goal);

  final int goal;
}
