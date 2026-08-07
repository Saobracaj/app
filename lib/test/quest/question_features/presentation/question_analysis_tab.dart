import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di.dart';
import '../../../../generated/locale_keys.g.dart';
import '../../../../theme/quiz_colors.dart';
import '../models/question_analytics.dart';
import '../state_management/question_analytics_bloc.dart';
import '../state_management/question_analytics_events.dart';
import '../state_management/question_analytics_state.dart';
import '../state_management/question_attempts_bloc.dart';
import '../state_management/question_attempts_events.dart';
import '../state_management/question_attempts_state.dart';

/// The "Анализа" tab. Four blocks, in the order they matter for revision:
///
/// 1. **what the question is worth** — expected points, i.e. the chance of it
///    turning up times the points it carries;
/// 2. **how likely it is to turn up**, with the exam's own structure behind it;
/// 3. **how hard it is** for everybody else (the only figure that comes from
///    the backend);
/// 4. **what its answer options give away** — phrases whose correctness is
///    settled across the whole question bank;
///
/// followed by the person's own attempt history, which is local (Drift) and
/// therefore always there.
///
/// Every number is stated with the evidence under it — the sample size, the
/// pool, the tally — because the point of the tab is that these are measured,
/// not guessed. Where a heuristic does *not* work (option length, echoing the
/// question's wording), that is said outright rather than left out.
class QuestionAnalysisTab extends StatelessWidget {
  const QuestionAnalysisTab({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<QuestionAnalyticsBloc>(param1: questionId)
            ..add(
              QuestionAnalyticsRequested(context.locale.languageCode),
            ),
        ),
        BlocProvider(
          create: (_) =>
              QuestionAttemptsBloc(questionId)..add(QuestionAttemptsRequested()),
        ),
      ],
      child: BlocBuilder<QuestionAnalyticsBloc, QuestionAnalyticsState>(
        builder: (context, state) {
          if (state.inProgress) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final analytics = state.analytics;
          final summary = state.summary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (analytics == null || summary == null)
                _Muted(LocaleKeys.questionAnalysis_unavailable.tr())
              else ...[
                _ValueBlock(analytics: analytics, summary: summary),
                _Gap(),
                _ProbabilityBlock(analytics: analytics, summary: summary),
                _Gap(),
                _DifficultyBlock(state: state),
                _Gap(),
                _KeywordsBlock(analytics: analytics, summary: summary),
                _Gap(),
              ],
              const _AttemptsBlock(),
              if (summary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Text(
                    LocaleKeys.questionAnalysis_source.tr(
                      args: ['${summary.exams}', '${summary.questions}'],
                    ),
                    style: _footnote(context),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

/// What the question is worth: `probability × points`, expressed both in exam
/// points and as a multiple of the average question, so "high" is a measured
/// statement rather than a label.
class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.analytics, required this.summary});

  final QuestionAnalytics analytics;
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    final (label, color) = switch (analytics.tier) {
      QuestionValueTier.high => (
        LocaleKeys.questionAnalysis_tierHigh.tr(),
        quiz.wrong,
      ),
      QuestionValueTier.medium => (
        LocaleKeys.questionAnalysis_tierMedium.tr(),
        quiz.warning,
      ),
      QuestionValueTier.low => (
        LocaleKeys.questionAnalysis_tierLow.tr(),
        quiz.correct,
      ),
      QuestionValueTier.none => (
        LocaleKeys.questionAnalysis_tierNone.tr(),
        Theme.of(context).colorScheme.outline,
      ),
    };

    return _Section(
      title: LocaleKeys.questionAnalysis_valueTitle.tr(),
      trailing: _Chip(label: label, color: color),
      children: [
        if (analytics.tier == QuestionValueTier.none)
          Text(
            LocaleKeys.questionAnalysis_valueNone.tr(
              args: ['${summary.exams}'],
            ),
            style: _body(context),
          )
        else ...[
          Text(
            LocaleKeys.questionAnalysis_valueDetail.tr(
              args: [
                _points(analytics.value),
                _points(summary.examPoints),
                _ratio(analytics.ratio),
              ],
            ),
            style: _body(context),
          ),
          const SizedBox(height: 4),
          Text(LocaleKeys.questionAnalysis_valueMethod.tr(), style: _footnote(context)),
        ],
      ],
    );
  }
}

/// The chance of the question being drawn, with the mechanism that produces it:
/// its pool and how many of that pool every exam takes.
class _ProbabilityBlock extends StatelessWidget {
  const _ProbabilityBlock({required this.analytics, required this.summary});

  final QuestionAnalytics analytics;
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    if (analytics.probability <= 0) {
      return _Section(
        title: LocaleKeys.questionAnalysis_probabilityTitle.tr(),
        trailing: _Chip(
          label: '0%',
          color: Theme.of(context).colorScheme.outline,
        ),
        children: [
          Text(
            LocaleKeys.questionAnalysis_valueNone.tr(args: ['${summary.exams}']),
            style: _body(context),
          ),
        ],
      );
    }

    return _Section(
      title: LocaleKeys.questionAnalysis_probabilityTitle.tr(),
      trailing: _Chip(
        label: _percent(analytics.probability),
        color: Theme.of(context).quiz.info,
      ),
      children: [
        Text(
          LocaleKeys.questionAnalysis_probabilityDetail.tr(
            args: ['${analytics.oneInExams}'],
          ),
          style: _body(context),
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.questionAnalysis_probabilityPool.tr(
            args: ['${analytics.poolSize}', '${analytics.poolSlots}'],
          ),
          style: _body(context),
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.questionAnalysis_probabilitySample.tr(
            args: ['${summary.exams}', '${analytics.sampleHits}'],
          ),
          style: _footnote(context),
        ),
        Text(
          LocaleKeys.questionAnalysis_probabilityMethod.tr(
            args: ['${summary.exams}'],
          ),
          style: _footnote(context),
        ),
      ],
    );
  }
}

/// The crowd difficulty. The only block whose absence is normal — a guest, a
/// question nobody has answered, or an unreachable backend all end here.
class _DifficultyBlock extends StatelessWidget {
  const _DifficultyBlock({required this.state});

  final QuestionAnalyticsState state;

  @override
  Widget build(BuildContext context) {
    final title = LocaleKeys.questionAnalysis_difficultyTitle.tr();
    if (state.difficultyInProgress) {
      return _Section(
        title: title,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    final difficulty = state.difficulty;
    if (difficulty == null) {
      final reason = state.difficultyRequiresSignIn
          ? LocaleKeys.questionAnalysis_difficultyGuest
          : state.difficultyFailed
          ? LocaleKeys.questionAnalysis_difficultyFailed
          : LocaleKeys.questionAnalysis_difficultyUnavailable;
      return _Section(
        title: title,
        children: [Text(reason.tr(), style: _body(context))],
      );
    }

    final quiz = Theme.of(context).quiz;
    final (comparison, color) = difficulty.isHarder
        ? (LocaleKeys.questionAnalysis_difficultyHarder, quiz.wrong)
        : difficulty.isEasier
        ? (LocaleKeys.questionAnalysis_difficultyEasier, quiz.correct)
        : (LocaleKeys.questionAnalysis_difficultyAverage, quiz.warning);

    return _Section(
      title: title,
      trailing: _Chip(
        label: LocaleKeys.questionAnalysis_difficultyValue.tr(
          args: [_wholePercent(difficulty.difficulty)],
        ),
        color: color,
      ),
      children: [
        Text(
          comparison.tr(args: [_wholePercent(difficulty.baseline)]),
          style: _body(context),
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.questionAnalysis_difficultySample.tr(
            args: ['${difficulty.attempts}', '${difficulty.learners}'],
          ),
          style: _footnote(context),
        ),
        if (!difficulty.isReliable)
          Text(
            LocaleKeys.questionAnalysis_difficultyThin.tr(),
            style: _footnote(context),
          ),
      ],
    );
  }
}

/// What the wording gives away: phrases that decide an option across the whole
/// bank, and the two option-shape heuristics — reported even though they turn
/// out not to work, because "length is not a hint" is itself the finding.
class _KeywordsBlock extends StatelessWidget {
  const _KeywordsBlock({required this.analytics, required this.summary});

  final QuestionAnalytics analytics;
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    return _Section(
      title: LocaleKeys.questionAnalysis_keywordsTitle.tr(),
      children: [
        if (analytics.markers.isEmpty)
          Text(LocaleKeys.questionAnalysis_keywordNone.tr(), style: _body(context))
        else
          for (final hit in analytics.markers)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: Icon(
                      hit.marker.kind.favoursCorrect
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 15,
                      color: hit.marker.kind.favoursCorrect
                          ? quiz.correct
                          : quiz.wrong,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocaleKeys.questionAnalysis_keywordOption.tr(
                            args: ['${hit.choiceIndex + 1}'],
                          ),
                          style: _footnote(context),
                        ),
                        Text(_markerText(hit.marker), style: _body(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        if (analytics.stemEchoes.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            LocaleKeys.questionAnalysis_keywordEcho.tr(
              args: [
                analytics.stemEchoes.map((i) => '${i + 1}').join(', '),
                _wholePercent(summary.echoCorrectRate),
                _wholePercent(summary.noEchoCorrectRate),
              ],
            ),
            style: _footnote(context),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          LocaleKeys.questionAnalysis_keywordLength.tr(
            args: [
              _wholePercent(summary.longestOptionCorrect),
              _wholePercent(summary.longestOptionChance),
            ],
          ),
          style: _footnote(context),
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.questionAnalysis_keywordsDisclaimer.tr(),
          style: _footnote(context),
        ),
      ],
    );
  }

  String _markerText(AnswerMarker marker) => switch (marker.kind) {
    MarkerKind.alwaysCorrect => LocaleKeys.questionAnalysis_keywordAlwaysCorrect
        .tr(args: [marker.phrase, '${marker.options}']),
    MarkerKind.alwaysWrong => LocaleKeys.questionAnalysis_keywordAlwaysWrong.tr(
      args: [marker.phrase, '${marker.options}'],
    ),
    MarkerKind.mostlyCorrect => LocaleKeys.questionAnalysis_keywordMostlyCorrect
        .tr(args: [marker.phrase, '${marker.correct}', '${marker.options}']),
    MarkerKind.mostlyWrong => LocaleKeys.questionAnalysis_keywordMostlyWrong.tr(
      args: [
        marker.phrase,
        '${marker.options - marker.correct}',
        '${marker.options}',
      ],
    ),
  };
}

/// The person's own history with this question — local, so it never loads.
class _AttemptsBlock extends StatelessWidget {
  const _AttemptsBlock();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuestionAttemptsBloc, QuestionAttemptsState>(
      builder: (context, state) {
        if (state.inProgress) return const SizedBox.shrink();
        return _Section(
          title: LocaleKeys.questionAnalysis_attemptsTitle.tr(),
          children: [
            if (state.attempts.isEmpty)
              Text(LocaleKeys.quest_noPreviousTries.tr(), style: _footnote(context))
            else ...[
              for (final (i, attempt) in state.attempts.reversed.indexed) ...[
                if (i > 0) const Divider(height: 1),
                _AttemptRow(date: attempt.date, isWrong: attempt.isWrong),
              ],
              const SizedBox(height: 4),
              Text(
                LocaleKeys.questionTabs_analysisSummary.tr(
                  args: ['${state.correctCount}', '${state.attempts.length}'],
                ),
                style: _footnote(context),
              ),
            ],
          ],
        );
      },
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

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

/// A titled block with an optional headline figure on the right.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// The block's headline figure — a tinted pill so the number reads at a glance.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 16);
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
    child: Text(text, style: _footnote(context)),
  );
}

TextStyle? _body(BuildContext context) => Theme.of(context).textTheme.bodySmall;

TextStyle? _footnote(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
  );
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

/// Exam points, to two decimals — most questions are worth hundredths of a
/// point per exam, so rounding further would show every one of them as "0.1".
String _points(double value) => value.toStringAsFixed(2);

/// A multiple of the average question. Below 1 the first decimal alone would
/// throw away most of the difference (0.15 and 0.14 both read as "0.1"), so
/// small multiples keep two.
String _ratio(double value) => switch (value) {
  >= 10 => value.toStringAsFixed(0),
  >= 1 => value.toStringAsFixed(1),
  _ => value.toStringAsFixed(2),
};

/// A probability like 0.0161 as "1.6%"; below 0.1% it would round to "0.0%", so
/// those get a second decimal.
String _percent(double value) {
  final percent = value * 100;
  return '${percent < 0.1 ? percent.toStringAsFixed(2) : percent.toStringAsFixed(1)}%';
}

/// A rate as a whole percentage, for figures where a decimal adds nothing.
String _wholePercent(double value) => (value * 100).round().toString();
