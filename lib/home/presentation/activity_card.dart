import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../data/home_preferences_repository.dart';
import '../domain/home_insights.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_events.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «Активность»: the streak, today's progress toward the daily goal, and a
/// calendar of the last weeks — one cell per day, darker the more answers
/// (one hue, four steps, measured against the goal).
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        final activity = state.activity;
        if (!state.loaded || activity == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final streakText = activity.streak == 0
            ? LocaleKeys.homeInsights_activity_noStreak.tr()
            : LocaleKeys.homeInsights_activity_streak.plural(activity.streak);
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_activity_title.tr(),
          icon: Icons.local_fire_department_outlined,
          trailing: IconButton(
            key: const ValueKey('activity_goal_button'),
            tooltip: LocaleKeys.homeInsights_activity_goalTitle.tr(),
            icon: const Icon(Icons.tune, size: 20),
            onPressed: () => _pickGoal(context, activity.dailyGoal),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                streakText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (activity.todayAnswers / activity.dailyGoal).clamp(
                    0.0,
                    1.0,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              HomeCaption(
                activity.goalReached
                    ? LocaleKeys.homeInsights_activity_goalReached.tr()
                    : LocaleKeys.homeInsights_activity_today.tr(
                        args: [
                          '${activity.todayAnswers}',
                          '${activity.dailyGoal}',
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              ActivityCalendar(activity: activity),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickGoal(BuildContext context, int current) async {
    final bloc = context.read<HomeInsightsBloc>();
    final goal = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(LocaleKeys.homeInsights_activity_goalTitle.tr()),
        children: [
          for (final option in HomePreferencesRepository.dailyGoalOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Row(
                children: [
                  Icon(
                    option == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    LocaleKeys.homeInsights_activity_goalOption.plural(option),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (goal != null && goal != current) bloc.add(HomeDailyGoalChanged(goal));
  }
}

/// The day grid: columns are weeks (Monday on top), the current week last;
/// as many weeks as fit the width, at most [maxWeeks].
class ActivityCalendar extends StatelessWidget {
  const ActivityCalendar({super.key, required this.activity});

  final ActivityInsight activity;

  static const cell = 12.0;
  static const gap = 3.0;
  static const maxWeeks = 26;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dayOf(clock.now());
    // The column of the current week ends on Sunday.
    final weekEnd = today.add(Duration(days: DateTime.sunday - today.weekday));
    return LayoutBuilder(
      builder: (context, constraints) {
        final weeks = ((constraints.maxWidth + gap) / (cell + gap))
            .floor()
            .clamp(1, maxWeeks);
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var w = weeks - 1; w >= 0; w--) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var d = 6; d >= 0; d--) ...[
                    _cellFor(
                      weekEnd.subtract(Duration(days: w * 7 + d)),
                      today,
                      scheme,
                    ),
                    if (d > 0) const SizedBox(height: gap),
                  ],
                ],
              ),
              if (w > 0) const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }

  Widget _cellFor(DateTime day, DateTime today, ColorScheme scheme) {
    final future = day.isAfter(today);
    final answers = activity.answersByDay[day] ?? 0;
    final Color color;
    if (future) {
      color = Colors.transparent;
    } else if (answers == 0) {
      color = scheme.surfaceContainerHighest;
    } else {
      color = scheme.primary.withValues(alpha: _intensity(answers));
    }
    return Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: day == today ? Border.all(color: scheme.primary) : null,
      ),
    );
  }

  /// Four steps of one hue, measured against the daily goal.
  double _intensity(int answers) {
    final share = answers / activity.dailyGoal;
    if (share >= 1) return 1;
    if (share >= 2 / 3) return 0.8;
    if (share >= 1 / 3) return 0.6;
    return 0.4;
  }
}
