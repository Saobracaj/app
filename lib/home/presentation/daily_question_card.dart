import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/analytics/analytics_service.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../../models/models.dart';
import '../../theme/quiz_colors.dart';
import '../state_management/daily_question_bloc.dart';
import '../state_management/daily_question_events.dart';
import '../state_management/daily_question_state.dart';
import 'home_card.dart';

/// «Вопрос дня»: one question answered right on the home screen — the text,
/// the picture if there is one, the options to tap, «проверить», the verdict
/// and a link to the question screen with its explanation.
class DailyQuestionCard extends StatelessWidget {
  const DailyQuestionCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailyQuestionBloc, DailyQuestionState>(
      builder: (context, state) {
        final question = state.question;
        if (question == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final quiz = theme.quiz;
        final showTranslation = context.select<FeatureFlagsBloc, bool>(
          (b) => b.state.russianContentForCategory(question.categoryId),
        );
        final translation = showTranslation ? question.translation : null;
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_dailyQuestion_title.tr(),
          icon: Icons.lightbulb_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (question.hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Image.asset(
                      'assets/img/${question.imageId}.jpeg',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(question.text, style: theme.textTheme.bodyLarge),
              if (translation != null && translation.isNotEmpty) ...[
                const SizedBox(height: 4),
                HomeCaption(translation, maxLines: 6),
              ],
              if (question.choicesReq > 1) ...[
                const SizedBox(height: 4),
                HomeCaption(
                  LocaleKeys.homeInsights_dailyQuestion_multiple.tr(
                    args: ['${question.choicesReq}'],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              for (var i = 0; i < question.choices.length; i++)
                _ChoiceRow(
                  index: i,
                  choice: question.choices[i],
                  translation: showTranslation
                      ? question.choices[i].translationRu
                      : null,
                  selected: state.selected.contains(i),
                  graded: state.graded,
                ),
              const SizedBox(height: 8),
              if (!state.graded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    key: const ValueKey('daily_question_check'),
                    onPressed: state.selected.isEmpty
                        ? null
                        : () => context.read<DailyQuestionBloc>().add(
                            DailyQuestionChecked(),
                          ),
                    child: Text(
                      LocaleKeys.homeInsights_dailyQuestion_check.tr(),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      state.correct ? Icons.check_circle : Icons.cancel,
                      color: state.correct ? quiz.correct : quiz.wrong,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.correct
                            ? LocaleKeys.homeInsights_dailyQuestion_correct.tr()
                            : LocaleKeys.homeInsights_dailyQuestion_wrong.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: state.correct ? quiz.correct : quiz.wrong,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        analytics.logHomeCardOpened(
                          card: AppFeature.homeDailyQuestion.key,
                          target: 'question',
                        );
                        Routemaster.of(
                          context,
                        ).push('/question/${question.id}');
                      },
                      child: Text(
                        LocaleKeys.homeInsights_dailyQuestion_open.tr(),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.index,
    required this.choice,
    required this.translation,
    required this.selected,
    required this.graded,
  });

  final int index;
  final Choice choice;
  final String? translation;
  final bool selected;
  final bool graded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    // After the check the verdict colours the rows: every right option in
    // green (missed ones included), a wrong pick in red.
    Color? tint;
    IconData icon = selected
        ? Icons.check_box_outlined
        : Icons.check_box_outline_blank;
    if (graded) {
      if (choice.isCorrect) {
        tint = quiz.correct;
        icon = Icons.check_circle_outline;
      } else if (selected) {
        tint = quiz.wrong;
        icon = Icons.highlight_off;
      }
    }
    return InkWell(
      key: ValueKey('daily_question_choice_$index'),
      borderRadius: BorderRadius.circular(8),
      onTap: graded
          ? null
          : () => context.read<DailyQuestionBloc>().add(
              DailyQuestionChoiceToggled(index),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: tint ?? theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choice.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tint,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                  if (translation != null && translation!.isNotEmpty)
                    HomeCaption(translation!, maxLines: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
