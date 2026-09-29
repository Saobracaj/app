import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/analytics/analytics_service.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';
import '../../test/start_test.dart';
import '../../theme/quiz_colors.dart';
import '../domain/home_insights.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «Слабые темы»: the three subcategories with the lowest current accuracy,
/// each with a bar and a «прогнать» button that runs the whole subcategory.
class WeakTopicsCard extends StatelessWidget {
  const WeakTopicsCard({super.key, this.wide = false});

  final bool wide;

  /// Answers a topic needs before it can be called weak — mirrors the default
  /// of `computeWeakTopics`.
  static const minAnswered = 5;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        if (!state.loaded) return const SizedBox.shrink();
        final topics = state.weakTopics;
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_weakTopics_title.tr(),
          icon: Icons.trending_down,
          child: topics.isEmpty
              ? HomeCaption(
                  LocaleKeys.homeInsights_weakTopics_empty.tr(
                    args: ['$minAnswered'],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < topics.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _TopicRow(topic: topics[i]),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final TopicInsight topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    final percent = (topic.accuracy * 100).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: topic.accuracy,
                  minHeight: 6,
                  color: topic.accuracy < 0.5 ? quiz.wrong : quiz.warning,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              HomeCaption(
                '${topic.correct}/${topic.answered} · '
                '${LocaleKeys.homeInsights_weakTopics_accuracy.tr(args: ['$percent'])}',
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () {
            analytics.logHomeCardOpened(
              card: AppFeature.homeWeakTopics.key,
              target: 'practice',
            );
            openStartTest(
              context,
              topic.questionIds,
              subcategory: '${topic.subcategoryId}',
            );
          },
          child: Text(LocaleKeys.homeInsights_weakTopics_practice.tr()),
        ),
      ],
    );
  }
}
