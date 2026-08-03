import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/widgets/confetti.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

const kMinPoints = 85;

/// The simulation result: a score ring as the single focal point, the verdict,
/// three stat tiles (correct / mistakes / time), the mistakes as cards with
/// image previews, and "review the mistakes" as the primary action. Renders in
/// the user's theme even after an exam-replica run (decision №4).
class FinalizePracticeWidget extends StatelessWidget {
  const FinalizePracticeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, allQuestions) {
        final data = allQuestions.questionsData!;
        return BlocBuilder<PracticeBloc, PracticeState>(
          builder: (context, state) {
            final points = state.finalPoints;
            final wrongIds = state.finalWrongQuestions;
            final isSuccess = points >= kMinPoints;
            final wrong = [
              for (final id in wrongIds)
                data.questions.firstWhere((q) => q.id == id),
            ];

            return Scaffold(
              bottomNavigationBar: _Actions(wrongIds: wrongIds),
              body: Stack(
                children: [
                  if (isSuccess) ConfettiDemo(),
                  SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _Hero(
                          points: points,
                          possibleScore: state.possibleScore,
                          isSuccess: isSuccess,
                          sameTheme:
                              wrong.length > 1 &&
                              wrong
                                      .map((q) => q.subcategoryId)
                                      .toSet()
                                      .length ==
                                  1,
                        ),
                        _StatTiles(
                          correct: state.questions.length - wrongIds.length,
                          wrong: wrongIds.length,
                          elapsedSeconds: state.elapsedSeconds,
                        ),
                        if (wrong.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _ErrorsHeader(wrong: wrong, data: data),
                          const SizedBox(height: 8),
                          for (final q in wrong) ...[
                            _ErrorCard(
                              question: q,
                              number: state.questions.indexOf(q.id) + 1,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The score ring with the verdict and its explanatory line underneath.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.points,
    required this.possibleScore,
    required this.isSuccess,
    required this.sameTheme,
  });

  final int points;
  final int possibleScore;
  final bool isSuccess;
  final bool sameTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    final fraction = possibleScore == 0
        ? 0.0
        : (points / possibleScore).clamp(0.0, 1.0);
    final subtitle = [
      LocaleKeys.simulation_threshold.tr(args: ['$kMinPoints']),
      if (sameTheme) LocaleKeys.simulation_sameTheme.tr(),
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 18),
      child: Column(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    color: quiz.correct,
                    backgroundColor: quiz.wrong,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$points',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocaleKeys.simulation_outOf.tr(
                          args: ['$possibleScore'],
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isSuccess
                ? LocaleKeys.simulation_success.tr()
                : LocaleKeys.simulation_fail.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The correct / mistakes / time tile row.
class _StatTiles extends StatelessWidget {
  const _StatTiles({
    required this.correct,
    required this.wrong,
    required this.elapsedSeconds,
  });

  final int correct;
  final int wrong;
  final int? elapsedSeconds;

  String get _time {
    final s = elapsedSeconds ?? 0;
    final minutes = s ~/ 60;
    final seconds = s % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    return Row(
      children: [
        _StatTile(
          value: '$correct',
          valueColor: quiz.correct,
          label: LocaleKeys.simulation_correct.tr(),
        ),
        const SizedBox(width: 8),
        _StatTile(
          value: '$wrong',
          valueColor: quiz.wrong,
          label: LocaleKeys.simulation_errorsShort.tr(),
        ),
        const SizedBox(width: 8),
        _StatTile(value: _time, label: LocaleKeys.simulation_time.tr()),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ваше грешке" with, when every mistake shares one subcategory, that
/// subcategory's name on the right — the pattern a user won't spot in a list.
class _ErrorsHeader extends StatelessWidget {
  const _ErrorsHeader({required this.wrong, required this.data});

  final List<Question> wrong;
  final QuestionsData data;

  String? get _sharedTopic {
    final ids = wrong.map((q) => q.subcategoryId).toSet();
    if (wrong.length < 2 || ids.length != 1) return null;
    for (final category in data.categories) {
      for (final sub in category.subcategories) {
        if (sub.id == ids.single) {
          final name = sub.description.trim();
          return name.endsWith(';') ? name.substring(0, name.length - 1) : name;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topic = _sharedTopic;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            LocaleKeys.simulation_yourErrors.tr(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (topic != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One mistake: image preview, question text, "Питање N · M поена", chevron.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.question, required this.number});

  final Question question;

  /// 1-based position of the question within the run.
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta =
        '${LocaleKeys.quest_navigatorQuestion.tr(args: ['$number'])}'
        ' · ${LocaleKeys.quest_points.plural(question.points)}';
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Routemaster.of(
          context,
        ).push('q?q=${question.id}&randomOptionsOrder=true'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Image.asset(
                    'assets/img/${question.imageId}.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.car_crash,
                      size: 36,
                      color: theme.colorScheme.secondary.withAlpha(50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned actions: review the mistakes (primary) and close. With a clean run
/// there is nothing to review, so closing becomes the primary action.
class _Actions extends StatelessWidget {
  const _Actions({required this.wrongIds});

  final List<int> wrongIds;

  @override
  Widget build(BuildContext context) {
    // Navigator.pop (not Routemaster) — the settings page awaits this pop to
    // refresh the previous-tries list.
    void close() => Navigator.of(context).pop();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wrongIds.isNotEmpty) ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Routemaster.of(
                    context,
                  ).push('/start?q=${wrongIds.join(',')}'),
                  child: Text(
                    LocaleKeys.simulation_reviewErrors.plural(wrongIds.length),
                  ),
                ),
                TextButton(
                  onPressed: close,
                  child: Text(LocaleKeys.simulation_close.tr()),
                ),
              ] else
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: close,
                  child: Text(LocaleKeys.simulation_close.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
