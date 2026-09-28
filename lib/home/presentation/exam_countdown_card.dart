import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../domain/home_insights.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_events.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «До экзамена»: an invitation to set the date, then the days left and what
/// the current pace promises by that day.
class ExamCountdownCard extends StatelessWidget {
  const ExamCountdownCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        if (!state.loaded) return const SizedBox.shrink();
        final countdown = state.countdown;
        final theme = Theme.of(context);
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_countdown_title.tr(),
          icon: Icons.event_outlined,
          trailing: countdown == null
              ? null
              : PopupMenuButton<_Action>(
                  key: const ValueKey('countdown_menu'),
                  onSelected: (action) => switch (action) {
                    _Action.change => _pickDate(context, countdown.examDate),
                    _Action.clear => context.read<HomeInsightsBloc>().add(
                      HomeExamDateChanged(null),
                    ),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _Action.change,
                      child: Text(
                        LocaleKeys.homeInsights_countdown_change.tr(),
                      ),
                    ),
                    PopupMenuItem(
                      value: _Action.clear,
                      child: Text(LocaleKeys.homeInsights_countdown_clear.tr()),
                    ),
                  ],
                ),
          child: countdown == null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('countdown_set'),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(LocaleKeys.homeInsights_countdown_set.tr()),
                    onPressed: () => _pickDate(context, null),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headline(countdown),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    HomeCaption(
                      DateFormat.yMMMMEEEEd(
                        context.locale.toString(),
                      ).format(countdown.examDate),
                      maxLines: 1,
                    ),
                    if (countdown.daysLeft > 0) ...[
                      const SizedBox(height: 8),
                      HomeCaption(
                        countdown.projectedPercent == null
                            ? LocaleKeys.homeInsights_countdown_noPace.tr()
                            : LocaleKeys.homeInsights_countdown_forecast.tr(
                                args: [
                                  '${countdown.pace.round()}',
                                  '${countdown.projectedPercent}',
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  String _headline(ExamCountdownInsight countdown) {
    if (countdown.daysLeft == 0) {
      return LocaleKeys.homeInsights_countdown_today.tr();
    }
    if (countdown.daysLeft < 0) {
      return LocaleKeys.homeInsights_countdown_passed.tr();
    }
    return LocaleKeys.homeInsights_countdown_days.plural(countdown.daysLeft);
  }

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final bloc = context.read<HomeInsightsBloc>();
    final today = dayOf(clock.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(today)
          ? current
          : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) bloc.add(HomeExamDateChanged(picked));
  }
}

enum _Action { change, clear }
