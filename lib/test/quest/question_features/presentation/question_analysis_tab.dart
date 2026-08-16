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

/// The "Анализа" tab. Three headline figures side by side, then the cues, then
/// the person's own history:
///
/// 1. **what the question is worth** — expected points, i.e. the chance of it
///    turning up times the points it carries;
/// 2. **how likely it is to turn up**, with the exam's own structure behind it;
/// 3. **how hard it is** for everybody else (the only figure that comes from
///    the backend);
/// 4. **key phrases** — cues a learner can memorise the answer by: whole
///    answers or phrases that are correct (or wrong) in every question of the
///    bank where they occur, and "word in the question → this answer" links.
///    Always Serbian wordings, whatever the interface language: the exam is
///    sat in Serbian and the options on screen are Serbian; the same phrases
///    are highlighted in the question text and the answer cards above;
///
/// followed by the person's own attempt history, which is local (Drift) and
/// therefore always there.
///
/// The three figures are graded, not quoted: a learner cannot tell whether
/// "2.6%" is a lot for one question out of 1559, so each cell shows *high /
/// medium / low* and nothing else. The number itself, the sentence behind it
/// and the method (sample size, pool, how it was computed) open in a dialog
/// when the cell is tapped — the tab reads at a glance and the evidence is a
/// tap away rather than in the way.
class QuestionAnalysisTab extends StatelessWidget {
  const QuestionAnalysisTab({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<QuestionAnalyticsBloc>(param1: questionId)
                ..add(QuestionAnalyticsRequested()),
        ),
        BlocProvider(
          create: (_) =>
              QuestionAttemptsBloc(questionId)
                ..add(QuestionAttemptsRequested()),
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
                _MetricsRow(
                  cells: [
                    _valueCell(context, analytics, summary),
                    _probabilityCell(context, analytics, summary),
                    _difficultyCell(context, state),
                  ],
                ),
                _Gap(),
                _KeywordsBlock(analytics: analytics, summary: summary),
                _Gap(),
              ],
              const _AttemptsBlock(),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The three headline figures
// ---------------------------------------------------------------------------

/// One column of the metrics table: a short title, a graded chip and, behind
/// a tap, the figure itself and the method it rests on.
class _Metric {
  const _Metric({
    required this.title,
    required this.dialogTitle,
    required this.label,
    required this.color,
    this.details,
    this.loading = false,
  });

  /// The short title over the chip.
  final String title;

  /// The full title of the details dialog.
  final String dialogTitle;

  /// The chip text — a grade, not a number.
  final String label;
  final Color color;

  /// What opens on tap; null when there is nothing more to say.
  final String? details;

  /// The chip is replaced by a spinner.
  final bool loading;
}

/// What the question is worth: `probability × points`, graded against the
/// average question. The number itself — points, and a multiple of the average
/// question — is in the dialog, so "high" stays a measured statement.
_Metric _valueCell(
  BuildContext context,
  QuestionAnalytics analytics,
  AnalyticsSummary summary,
) {
  final (label, color) = _grade(context, analytics.tier);
  final detail = analytics.tier == QuestionValueTier.none
      ? LocaleKeys.questionAnalysis_valueNone.tr(args: ['${summary.exams}'])
      : LocaleKeys.questionAnalysis_valueDetail.tr(
          args: [
            _points(analytics.value),
            _points(summary.examPoints),
            _ratio(analytics.ratio),
          ],
        );
  return _Metric(
    title: LocaleKeys.questionAnalysis_valueShort.tr(),
    dialogTitle: LocaleKeys.questionAnalysis_valueTitle.tr(),
    label: label,
    color: color,
    details: _paragraphs([
      detail,
      LocaleKeys.questionAnalysis_valueHelp.tr(
        args: ['${summary.exams}', '${summary.questions}'],
      ),
    ]),
  );
}

/// The chance of the question being drawn, graded against the average
/// question; the percentage, the pool and how many of that pool every exam
/// takes are in the dialog.
_Metric _probabilityCell(
  BuildContext context,
  QuestionAnalytics analytics,
  AnalyticsSummary summary,
) {
  final tier = analytics.probabilityTier(summary);
  final quiz = Theme.of(context).quiz;
  final (label, color) = switch (tier) {
    QuestionValueTier.high => (
      LocaleKeys.questionAnalysis_probabilityHigh.tr(),
      quiz.wrong,
    ),
    QuestionValueTier.medium => (
      LocaleKeys.questionAnalysis_probabilityMedium.tr(),
      quiz.warning,
    ),
    QuestionValueTier.low => (
      LocaleKeys.questionAnalysis_probabilityLow.tr(),
      quiz.correct,
    ),
    QuestionValueTier.none => (
      LocaleKeys.questionAnalysis_probabilityNone.tr(),
      Theme.of(context).colorScheme.outline,
    ),
  };
  final detail = tier == QuestionValueTier.none
      ? LocaleKeys.questionAnalysis_valueNone.tr(args: ['${summary.exams}'])
      : LocaleKeys.questionAnalysis_probabilityDetail.tr(
          args: [_percent(analytics.probability), '${analytics.oneInExams}'],
        );
  return _Metric(
    title: LocaleKeys.questionAnalysis_probabilityShort.tr(),
    dialogTitle: LocaleKeys.questionAnalysis_probabilityTitle.tr(),
    label: label,
    color: color,
    details: _paragraphs([
      detail,
      LocaleKeys.questionAnalysis_probabilityHelp.tr(
        args: [
          '${analytics.poolSize}',
          '${analytics.poolSlots}',
          '${summary.exams}',
          '${analytics.sampleHits}',
          '${summary.exams}',
        ],
      ),
    ]),
  );
}

/// The crowd difficulty. The only figure whose absence is normal — a guest, a
/// question nobody has answered, or an unreachable backend all end in a
/// neutral chip that says which of the three it is.
_Metric _difficultyCell(BuildContext context, QuestionAnalyticsState state) {
  final title = LocaleKeys.questionAnalysis_difficultyTitle.tr();
  final neutral = Theme.of(context).colorScheme.outline;
  if (state.difficultyInProgress) {
    return _Metric(
      title: title,
      dialogTitle: title,
      label: '',
      color: neutral,
      loading: true,
    );
  }

  final difficulty = state.difficulty;
  if (difficulty == null) {
    final (chip, reason) = state.difficultyRequiresSignIn
        ? (
            LocaleKeys.questionAnalysis_difficultyGuestChip,
            LocaleKeys.questionAnalysis_difficultyGuest,
          )
        : state.difficultyFailed
        ? (
            LocaleKeys.questionAnalysis_difficultyFailedChip,
            LocaleKeys.questionAnalysis_difficultyFailed,
          )
        : (
            LocaleKeys.questionAnalysis_difficultyNoDataChip,
            LocaleKeys.questionAnalysis_difficultyUnavailable,
          );
    return _Metric(
      title: title,
      dialogTitle: title,
      label: chip.tr(),
      color: neutral,
      details: reason.tr(),
    );
  }

  final quiz = Theme.of(context).quiz;
  final (label, color, comparison) = switch (difficulty.tier) {
    QuestionValueTier.high => (
      LocaleKeys.questionAnalysis_difficultyHigh.tr(),
      quiz.wrong,
      LocaleKeys.questionAnalysis_difficultyHarder,
    ),
    QuestionValueTier.low => (
      LocaleKeys.questionAnalysis_difficultyLow.tr(),
      quiz.correct,
      LocaleKeys.questionAnalysis_difficultyEasier,
    ),
    _ => (
      LocaleKeys.questionAnalysis_difficultyMedium.tr(),
      quiz.warning,
      LocaleKeys.questionAnalysis_difficultyAverage,
    ),
  };
  final baseline = _wholePercent(difficulty.baseline);
  final rate = LocaleKeys.questionAnalysis_difficultyValue.tr(
    args: [_wholePercent(difficulty.difficulty)],
  );
  final thin = difficulty.isReliable
      ? ''
      : '\n${LocaleKeys.questionAnalysis_difficultyThin.tr()}';
  return _Metric(
    title: title,
    dialogTitle: title,
    label: label,
    color: color,
    details: _paragraphs([
      '$rate. ${comparison.tr(args: [baseline])}.$thin',
      LocaleKeys.questionAnalysis_difficultyHelp.tr(
        args: ['${difficulty.attempts}', '${difficulty.learners}', baseline],
      ),
    ]),
  );
}

/// The label and colour of a value tier: high is red (must not be skipped),
/// low is green, "never appears" is neutral.
(String, Color) _grade(BuildContext context, QuestionValueTier tier) {
  final quiz = Theme.of(context).quiz;
  return switch (tier) {
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
}

String _paragraphs(List<String> parts) => parts.join('\n\n');

/// The three metrics as one row of equal columns, each a tappable cell.
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.cells});

  final List<_Metric> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // IntrinsicHeight so that a two-line title in one column does not leave
      // its neighbours' chips misaligned: every cell gets the row's height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final cell in cells)
              Expanded(child: _MetricCell(metric: cell)),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = metric.details;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: details == null
          ? null
          : () => _showDetails(context, metric.dialogTitle, details),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          children: [
            Text(
              metric.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const SizedBox(height: 6),
            if (metric.loading)
              const Padding(
                padding: EdgeInsets.all(4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              _Chip(label: metric.label, color: metric.color),
          ],
        ),
      ),
    );
  }
}

/// The details of a headline figure, in a dialog rather than a hover tooltip:
/// the texts are several sentences, and most readers are on a phone, where a
/// tooltip would vanish under the finger.
void _showDetails(BuildContext context, String title, String text) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

/// Key phrases: what a learner can memorise the answer by. The cues that hold
/// across the whole bank — the whole answer being always correct or always
/// wrong, a phrase inside it that is, and "word in the question → this answer"
/// links — as one flat list. Every cue quotes its wording in full: the
/// options are shuffled on screen, so "option 3" would point nowhere, and the
/// same wordings are highlighted in the question and the cards above.
class _KeywordsBlock extends StatelessWidget {
  const _KeywordsBlock({required this.analytics, required this.summary});

  final QuestionAnalytics analytics;
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final cues = analytics.cues;
    return _Section(
      title: LocaleKeys.questionAnalysis_keywordsTitle.tr(),
      help: LocaleKeys.questionAnalysis_keywordsHelp.tr(
        args: ['${summary.questions}', '${summary.markerQuestions}'],
      ),
      children: [
        if (cues.isEmpty)
          Text(
            LocaleKeys.questionAnalysis_keywordNone.tr(),
            style: _body(context),
          )
        else ...[
          for (final cue in cues) _CueRow(cue: cue),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.questionAnalysis_keywordsHighlighted.tr(),
            style: _footnote(context),
          ),
        ],
      ],
    );
  }
}

/// The sentence for one cue, always quoting the Serbian wording in full.
String _cueText(QuestionCue cue) => switch (cue) {
  MarkerCue(:final marker) => switch ((marker.whole, marker.kind)) {
    (true, MarkerKind.alwaysCorrect) =>
      LocaleKeys.questionAnalysis_keywordWholeCorrect.tr(
        args: [marker.phrase, '${marker.options}'],
      ),
    (true, MarkerKind.alwaysWrong) =>
      LocaleKeys.questionAnalysis_keywordWholeWrong.tr(
        args: [marker.phrase, '${marker.options}'],
      ),
    (false, MarkerKind.alwaysCorrect) =>
      LocaleKeys.questionAnalysis_keywordPhraseCorrect.tr(
        args: [marker.phrase, '${marker.options}'],
      ),
    (false, MarkerKind.alwaysWrong) =>
      LocaleKeys.questionAnalysis_keywordPhraseWrong.tr(
        args: [marker.phrase, '${marker.options}'],
      ),
  },
  LinkCue(:final link) => LocaleKeys.questionAnalysis_keywordLink.tr(
    args: [link.stem, link.answer, '${link.questions}'],
  ),
};

/// One line of the key-phrases block: a marker or a link, with the verdict
/// icon.
class _CueRow extends StatelessWidget {
  const _CueRow({required this.cue});

  final QuestionCue cue;

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Icon(
              switch (cue) {
                LinkCue() => Icons.link,
                MarkerCue() =>
                  cue.favoursCorrect
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
              },
              size: 15,
              color: cue.favoursCorrect ? quiz.correct : quiz.wrong,
            ),
          ),
          Expanded(child: Text(_cueText(cue), style: _body(context))),
        ],
      ),
    );
  }
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
              Text(
                LocaleKeys.quest_noPreviousTries.tr(),
                style: _footnote(context),
              )
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

/// A titled block and, when [help] is given, a "?" button after the title
/// that opens the explanation in a dialog — the long text stays out of the way
/// until it is asked for.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.help});

  final String title;
  final String? help;
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
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (help case final help?) _HelpButton(title: title, text: help),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// The "?" next to a block title. Tapping it opens the block's explanation in
/// a dialog rather than a hover tooltip: the texts are several sentences, and
/// most readers are on a phone, where a tooltip would vanish under the finger.
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
      icon: Icon(
        Icons.help_outline,
        size: 17,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
      tooltip: LocaleKeys.questionAnalysis_helpTooltip.tr(),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

/// A metric's grade — a tinted pill so it reads at a glance. Wraps rather
/// than clips: three columns on a phone leave each chip little room, and
/// "Не појављује се" has to fit.
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
        textAlign: TextAlign.center,
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
