import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «Сводка»: four stat tiles — answers in total, accuracy over the week,
/// simulations taken and the time spent in them.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        final summary = state.summary;
        if (!state.loaded || summary == null) return const SizedBox.shrink();
        final accuracy = summary.weekAccuracy;
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_summary_title.tr(),
          icon: Icons.insights_outlined,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Tile(
                value: '${summary.totalAnswers}',
                label: LocaleKeys.homeInsights_summary_answers.tr(),
              ),
              _Tile(
                value: accuracy == null ? '—' : '${(accuracy * 100).round()}%',
                label: LocaleKeys.homeInsights_summary_weekAccuracy.tr(),
              ),
              _Tile(
                value: '${summary.simulations}',
                label: LocaleKeys.homeInsights_summary_simulations.tr(),
              ),
              _Tile(
                value: formatStudyTime(summary.simulationSeconds),
                label: LocaleKeys.homeInsights_summary_simulationTime.tr(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// `1 ч 20 мин` / `45 мин` — hours only once there are any.
String formatStudyTime(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return LocaleKeys.homeInsights_summary_minutes.tr(args: ['$minutes']);
  }
  return LocaleKeys.homeInsights_summary_hoursMinutes.tr(
    args: ['${minutes ~/ 60}', '${minutes % 60}'],
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          HomeCaption(label),
        ],
      ),
    );
  }
}
