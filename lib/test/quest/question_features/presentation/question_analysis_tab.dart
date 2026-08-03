import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/locale_keys.g.dart';
import '../../../../theme/quiz_colors.dart';
import '../state_management/question_attempts_bloc.dart';
import '../state_management/question_attempts_events.dart';
import '../state_management/question_attempts_state.dart';

/// The "Анализа" tab: previous attempts on this question (newest first) and a
/// correct-of-total summary. Data is local (Drift), so there is no loading UI.
class QuestionAnalysisTab extends StatelessWidget {
  const QuestionAnalysisTab({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          QuestionAttemptsBloc(questionId)..add(QuestionAttemptsRequested()),
      child: BlocBuilder<QuestionAttemptsBloc, QuestionAttemptsState>(
        builder: (context, state) {
          final theme = Theme.of(context);
          final muted = theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          );
          if (state.inProgress) return const SizedBox.shrink();
          if (state.attempts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text(LocaleKeys.quest_noPreviousTries.tr(), style: muted),
            );
          }
          final attempts = state.attempts.reversed.toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < attempts.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _AttemptRow(
                        date: attempts[i].date,
                        isWrong: attempts[i].isWrong,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Text(
                  LocaleKeys.questionTabs_analysisSummary.tr(
                    args: ['${state.correctCount}', '${state.attempts.length}'],
                  ),
                  style: muted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.date, required this.isWrong});

  final DateTime date;
  final bool isWrong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: isWrong ? quiz.wrong : quiz.correct,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(_format(context), style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            (isWrong
                    ? LocaleKeys.questionTabs_attemptWrong
                    : LocaleKeys.questionTabs_attemptCorrect)
                .tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// "28. јул" within the current year, with the year appended otherwise.
  String _format(BuildContext context) {
    final locale = context.locale.toString();
    return date.year == DateTime.now().year
        ? DateFormat.MMMd(locale).format(date)
        : DateFormat.yMMMd(locale).format(date);
  }
}
