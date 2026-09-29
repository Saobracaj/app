import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../db/answer_repository.dart';
import '../../db/db.dart' show PracticeRecord;
import '../../konspekt/data/konspekt_repository.dart';
import '../../models/models.dart';
import '../../test/quest/question_features/data/question_analytics_repository.dart';
import '../data/home_preferences_repository.dart';
import '../domain/home_insights.dart';
import 'home_insights_events.dart';
import 'home_insights_state.dart';

/// Computes the figures behind the home-screen cards (see `home_insights.dart`)
/// from the local answer history, the question bank and the exam blueprint,
/// and keeps them fresh: any write to the statistics tables — an answer, a
/// finished simulation, a sync merge, the wipe on sign-out — triggers a
/// recomputation, so the cards never show yesterday's numbers after a run.
///
/// Recomputing is cheap (one pass over ~1.5k questions and a few hundred
/// rows) but bursts of writes are common — a quiz records every answer — so
/// the table signal is debounced.
@injectable
class HomeInsightsBloc extends Bloc<HomeInsightsEvent, HomeInsightsState> {
  HomeInsightsBloc(
    this._answers,
    this._analytics,
    this._preferences,
    this._konspekts,
  ) : super(const HomeInsightsState()) {
    on<HomeInsightsQuestionsChanged>(_onQuestionsChanged);
    on<HomeInsightsRefreshRequested>(_onRefreshRequested);
    on<HomeExamDateChanged>(_onExamDateChanged);
    on<HomeDailyGoalChanged>(_onDailyGoalChanged);
    _changes = _answers.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(
        refreshDebounce,
        () => add(HomeInsightsRefreshRequested()),
      );
    });
  }

  /// How long after the last statistics write the recomputation runs.
  static const refreshDebounce = Duration(milliseconds: 300);

  final AnswerRepository _answers;
  final QuestionAnalyticsRepository _analytics;
  final HomePreferencesRepository _preferences;
  final KonspektRepository _konspekts;

  StreamSubscription<void>? _changes;
  Timer? _debounce;
  QuestionsData? _data;

  Future<void> _onQuestionsChanged(
    HomeInsightsQuestionsChanged event,
    Emitter<HomeInsightsState> emit,
  ) async {
    _data = event.data;
    await _recompute(emit);
  }

  Future<void> _onRefreshRequested(
    HomeInsightsRefreshRequested event,
    Emitter<HomeInsightsState> emit,
  ) => _recompute(emit);

  Future<void> _onExamDateChanged(
    HomeExamDateChanged event,
    Emitter<HomeInsightsState> emit,
  ) async {
    await _preferences.setExamDate(event.date);
    await _recompute(emit);
  }

  Future<void> _onDailyGoalChanged(
    HomeDailyGoalChanged event,
    Emitter<HomeInsightsState> emit,
  ) async {
    await _preferences.setDailyGoal(event.goal);
    await _recompute(emit);
  }

  Future<void> _recompute(Emitter<HomeInsightsState> emit) async {
    final data = _data;
    if (data == null) return;
    final now = clock.now();
    final results = await Future.wait<Object?>([
      _answers.getLastAnswers(),
      _answers.getDailyActivity(),
      _answers.getPracticeRecords(),
      _analytics.weights(),
      _preferences.examDate(),
      _preferences.dailyGoal(),
      _konspekts.lastOpened(),
    ]);
    if (emit.isDone) return;
    final lastAnswers = results[0] as Map<int, bool>;
    final days = results[1] as List<DayActivity>;
    final records = results[2] as List<PracticeRecord>;
    final weights = results[3] as Map<int, double>;
    final examDate = results[4] as DateTime?;
    final goal = results[5] as int;
    final lastKonspekt = results[6] as String?;

    final readiness = computeReadiness(
      questions: data.questions,
      lastAnswers: lastAnswers,
      weights: weights,
    );
    final weakTopics = computeWeakTopics(
      questions: data.questions,
      categories: data.categories,
      lastAnswers: lastAnswers,
    );
    final weakest = readiness.weakestSubcategoryId;
    final konspektName = lastKonspekt == null
        ? null
        : data.categories
              .where((c) => c.id == lastKonspekt)
              .map((c) => c.name)
              .firstOrNull;
    emit(
      state.copyWith(
        loaded: true,
        readiness: readiness,
        weakestTopic: weakest == null
            ? null
            : _topic(data, weakest, lastAnswers),
        examTrend: computeExamTrend(records),
        activity: computeActivity(days: days, now: now, dailyGoal: goal),
        weakTopics: weakTopics,
        coverage: computeCoverage(
          questions: data.questions,
          categories: data.categories,
          lastAnswers: lastAnswers,
        ),
        countdown: examDate == null
            ? null
            : computeCountdown(
                examDate: examDate,
                now: now,
                days: days,
                answeredDistinct: lastAnswers.length,
                total: data.questions.length,
              ),
        summary: computeSummary(days: days, records: records, now: now),
        lastKonspekt: konspektName == null
            ? null
            : LastKonspektInsight(
                categoryId: lastKonspekt!,
                name: konspektName,
              ),
      ),
    );
  }

  /// The [subcategoryId] as a topic, whatever its accuracy — the readiness
  /// card's «подтянуть» target is not held to the weak-topics threshold.
  TopicInsight _topic(
    QuestionsData data,
    int subcategoryId,
    Map<int, bool> lastAnswers,
  ) {
    final questions = data.questions
        .where((q) => q.subcategoryId == subcategoryId)
        .toList();
    String? title;
    String categoryId = '';
    for (final c in data.categories) {
      for (final s in c.subcategories) {
        if (s.id == subcategoryId) {
          title = s.description;
          categoryId = c.id;
        }
      }
    }
    return TopicInsight(
      subcategoryId: subcategoryId,
      categoryId: categoryId,
      title: title ?? '$subcategoryId',
      answered: questions.where((q) => lastAnswers.containsKey(q.id)).length,
      correct: questions.where((q) => lastAnswers[q.id] == false).length,
      questionIds: [for (final q in questions) q.id],
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _changes?.cancel();
    return super.close();
  }
}
