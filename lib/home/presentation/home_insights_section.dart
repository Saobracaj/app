import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../core/presentation/wide_layout.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../../questions/state_management/all_questions_bloc.dart';
import '../state_management/daily_question_bloc.dart';
import '../state_management/daily_question_events.dart';
import '../state_management/daily_sign_bloc.dart';
import '../state_management/daily_sign_events.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_events.dart';
import '../state_management/home_insights_state.dart';
import 'activity_card.dart';
import 'category_coverage_card.dart';
import 'continue_konspekt_card.dart';
import 'daily_question_card.dart';
import 'daily_sign_card.dart';
import 'exam_countdown_card.dart';
import 'exam_trend_card.dart';
import 'readiness_card.dart';
import 'summary_card.dart';
import 'weak_topics_card.dart';

/// The progress block of the home screen: every card is its own feature flag
/// (`AppFeature.homeCards`), so the block renders whichever are on and
/// disappears entirely when none is. The simulations card has one more
/// condition — at least one simulation taken; until then it is not shown.
///
/// Only the cards in [order] stand on the screen (SAOBR-506); the other cards
/// of `lib/home/presentation/` are kept in code but marked
/// `AppFeature.shelved` and never rendered.
///
/// All figures come from the device — the local answer history, the bundled
/// bank and blueprint, the pravilnik index — so the block is the same online
/// and offline and for a guest.
///
/// On the phone the cards stack in one column; on a wide screen the compact
/// ones form a grid and the wide ones (weak topics, the question of the day,
/// the category coverage) span the column.
class HomeInsightsSection extends StatelessWidget {
  const HomeInsightsSection({super.key, this.wide = false});

  final bool wide;

  /// Screen order of the cards: the summary first, then the activity, then
  /// the exam simulations.
  static const order = [
    AppFeature.homeSummary,
    AppFeature.homeActivity,
    AppFeature.homeExamTrend,
  ];

  /// Cards that take a whole row on the wide layout.
  static const _fullWidth = {
    AppFeature.homeWeakTopics,
    AppFeature.homeDailyQuestion,
    AppFeature.homeCategoryCoverage,
  };

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlagsBloc>().state;
    final enabled = [
      for (final feature in order)
        if (flags.isEnabled(feature)) feature,
    ];
    if (enabled.isEmpty) return const SizedBox.shrink();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => getIt<HomeInsightsBloc>()
            ..add(
              HomeInsightsQuestionsChanged(
                context.read<AllQuestionsBloc>().state.questionsData,
              ),
            ),
        ),
        // The question and the sign of the day read the bank and the
        // pravilnik — only worth starting when their cards are on screen.
        if (enabled.contains(AppFeature.homeDailyQuestion))
          BlocProvider(create: (_) => getIt<DailyQuestionBloc>()),
        if (enabled.contains(AppFeature.homeDailySign))
          BlocProvider(
            create: (_) => getIt<DailySignBloc>()..add(DailySignStarted()),
          ),
      ],
      child: BlocListener<AllQuestionsBloc, AllQuestionsBlocState>(
        listenWhen: (previous, next) =>
            previous.questionsData != next.questionsData,
        listener: (context, state) {
          context.read<HomeInsightsBloc>().add(
            HomeInsightsQuestionsChanged(state.questionsData),
          );
          _startDailyQuestion(context, state);
        },
        child: Builder(
          builder: (context) {
            // The bank may already be loaded when the block first appears.
            _startDailyQuestion(
              context,
              context.read<AllQuestionsBloc>().state,
            );
            return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
              buildWhen: (previous, next) =>
                  (previous.examTrend == null) != (next.examTrend == null),
              builder: (context, state) {
                final visible = [
                  for (final feature in enabled)
                    if (feature != AppFeature.homeExamTrend ||
                        state.examTrend != null)
                      feature,
                ];
                if (visible.isEmpty) return const SizedBox.shrink();
                return wide ? _wide(context, visible) : _narrow(visible);
              },
            );
          },
        ),
      ),
    );
  }

  static void _startDailyQuestion(
    BuildContext context,
    AllQuestionsBlocState state,
  ) {
    final data = state.questionsData;
    if (data == null) return;
    final bloc = context.read<DailyQuestionBloc?>();
    if (bloc == null) return;
    if (bloc.state.question != null) return;
    bloc.add(DailyQuestionStarted(data.questions));
  }

  Widget _narrow(List<AppFeature> enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final feature in enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: _card(feature, wide: false),
          ),
      ],
    );
  }

  Widget _wide(BuildContext context, List<AppFeature> enabled) {
    final compact = enabled.where((f) => !_fullWidth.contains(f)).toList();
    final full = enabled.where(_fullWidth.contains).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: LocaleKeys.homeInsights_section.tr()),
        if (compact.isNotEmpty)
          ResponsiveGrid(
            minItemWidth: 320,
            spacing: 16,
            runSpacing: 16,
            children: [for (final f in compact) _card(f, wide: true)],
          ),
        for (final feature in full)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _card(feature, wide: true),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(AppFeature feature, {required bool wide}) => switch (feature) {
    AppFeature.homeReadiness => ReadinessCard(wide: wide),
    AppFeature.homeExamTrend => ExamTrendCard(wide: wide),
    AppFeature.homeActivity => ActivityCard(wide: wide),
    AppFeature.homeWeakTopics => WeakTopicsCard(wide: wide),
    AppFeature.homeCategoryCoverage => CategoryCoverageCard(wide: wide),
    AppFeature.homeDailyQuestion => DailyQuestionCard(wide: wide),
    AppFeature.homeExamCountdown => ExamCountdownCard(wide: wide),
    AppFeature.homeDailySign => DailySignCard(wide: wide),
    AppFeature.homeContinueKonspekt => ContinueKonspektCard(wide: wide),
    AppFeature.homeSummary => SummaryCard(wide: wide),
    _ => const SizedBox.shrink(),
  };
}
