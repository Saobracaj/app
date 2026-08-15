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
/// 4. **key phrases** — cues a learner can memorise the answer by: whole
///    answers or phrases that are correct (or wrong) in every question of the
///    bank where they occur, and "word in the question → this answer" links.
///    Always Serbian wordings, whatever the interface language: the exam is
///    sat in Serbian and the options on screen are Serbian;
///
/// followed by the person's own attempt history, which is local (Drift) and
/// therefore always there.
///
/// Each block is one headline figure and one line of text; the method behind
/// the number — the sample size, the pool, how it was computed — sits behind
/// the block's "?" button, so the tab reads at a glance and the evidence is a
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
              const SizedBox(height: 12),
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
      help: LocaleKeys.questionAnalysis_valueHelp.tr(
        args: ['${summary.exams}', '${summary.questions}'],
      ),
      children: [
        if (analytics.tier == QuestionValueTier.none)
          Text(
            LocaleKeys.questionAnalysis_valueNone.tr(
              args: ['${summary.exams}'],
            ),
            style: _body(context),
          )
        else
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
    final help = LocaleKeys.questionAnalysis_probabilityHelp.tr(
      args: [
        '${analytics.poolSize}',
        '${analytics.poolSlots}',
        '${summary.exams}',
        '${analytics.sampleHits}',
        '${summary.exams}',
      ],
    );
    if (analytics.probability <= 0) {
      return _Section(
        title: LocaleKeys.questionAnalysis_probabilityTitle.tr(),
        trailing: _Chip(
          label: '0%',
          color: Theme.of(context).colorScheme.outline,
        ),
        help: help,
        children: [
          Text(
            LocaleKeys.questionAnalysis_valueNone.tr(
              args: ['${summary.exams}'],
            ),
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
      help: help,
      children: [
        Text(
          LocaleKeys.questionAnalysis_probabilityDetail.tr(
            args: ['${analytics.oneInExams}'],
          ),
          style: _body(context),
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
      help: LocaleKeys.questionAnalysis_difficultyHelp.tr(
        args: [
          '${difficulty.attempts}',
          '${difficulty.learners}',
          _wholePercent(difficulty.baseline),
        ],
      ),
      children: [
        Text(
          comparison.tr(args: [_wholePercent(difficulty.baseline)]),
          style: _body(context),
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

/// Key phrases: what a learner can memorise the answer by. Per option, the cues
/// that hold across the whole bank — the whole answer being always correct or
/// always wrong, a phrase inside it that is, and "word in the question → this
/// answer" links. At most [_maxCuesPerOption] marker cues are shown per
/// option, whole-answer cues first and then by how much evidence they carry;
/// links are rare enough to always show.
class _KeywordsBlock extends StatelessWidget {
  const _KeywordsBlock({required this.analytics, required this.summary});

  final QuestionAnalytics analytics;
  final AnalyticsSummary summary;

  static const int _maxCuesPerOption = 2;

  @override
  Widget build(BuildContext context) {
    final byOption = _cuesByOption();
    return _Section(
      title: LocaleKeys.questionAnalysis_keywordsTitle.tr(),
      help: LocaleKeys.questionAnalysis_keywordsHelp.tr(
        args: ['${summary.questions}', '${summary.markerQuestions}'],
      ),
      children: [
        if (byOption.isEmpty)
          Text(
            LocaleKeys.questionAnalysis_keywordNone.tr(),
            style: _body(context),
          )
        else
          for (final MapEntry(key: option, value: cues) in byOption.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.questionAnalysis_keywordOption.tr(
                      args: ['${option + 1}'],
                    ),
                    style: _footnote(context),
                  ),
                  for (final cue in cues) _CueRow(cue: cue),
                ],
              ),
            ),
      ],
    );
  }

  /// Option index → its cues, in option order; options without any are absent.
  Map<int, List<_Cue>> _cuesByOption() {
    final markers = <int, List<AnswerMarker>>{};
    for (final hit in analytics.markers) {
      (markers[hit.choiceIndex] ??= []).add(hit.marker);
    }
    final links = <int, List<AnswerLink>>{};
    for (final hit in analytics.links) {
      (links[hit.choiceIndex] ??= []).add(hit.link);
    }

    final options = {...markers.keys, ...links.keys}.toList()..sort();
    return {
      for (final option in options)
        option: [
          for (final marker in _ranked(markers[option]).take(_maxCuesPerOption))
            _Cue.marker(marker),
          for (final link in links[option] ?? const <AnswerLink>[])
            _Cue.link(link),
        ],
    };
  }

  /// Whole-answer cues first, then the best-evidenced phrase.
  static List<AnswerMarker> _ranked(List<AnswerMarker>? markers) =>
      [...?markers]..sort(
        (a, b) => a.whole != b.whole
            ? (a.whole ? -1 : 1)
            : b.options.compareTo(a.options),
      );
}

/// One line of the key-phrases block: a marker or a link, with the verdict icon.
class _Cue {
  const _Cue.marker(AnswerMarker this.marker) : link = null;
  const _Cue.link(AnswerLink this.link) : marker = null;

  final AnswerMarker? marker;
  final AnswerLink? link;

  bool get favoursCorrect => marker?.kind.favoursCorrect ?? true;

  String text() {
    final marker = this.marker;
    if (marker != null) {
      return switch ((marker.whole, marker.kind)) {
        (true, MarkerKind.alwaysCorrect) =>
          LocaleKeys.questionAnalysis_keywordWholeCorrect.tr(
            args: ['${marker.options}'],
          ),
        (true, MarkerKind.alwaysWrong) =>
          LocaleKeys.questionAnalysis_keywordWholeWrong.tr(
            args: ['${marker.options}'],
          ),
        (false, MarkerKind.alwaysCorrect) =>
          LocaleKeys.questionAnalysis_keywordPhraseCorrect.tr(
            args: [marker.phrase, '${marker.options}'],
          ),
        (false, MarkerKind.alwaysWrong) =>
          LocaleKeys.questionAnalysis_keywordPhraseWrong.tr(
            args: [marker.phrase, '${marker.options}'],
          ),
      };
    }
    final link = this.link!;
    return LocaleKeys.questionAnalysis_keywordLink.tr(
      args: [link.stem, '${link.questions}'],
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.cue});

  final _Cue cue;

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
              cue.link != null
                  ? Icons.link
                  : cue.favoursCorrect
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              size: 15,
              color: cue.favoursCorrect ? quiz.correct : quiz.wrong,
            ),
          ),
          Expanded(child: Text(cue.text(), style: _body(context))),
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

/// A titled block with an optional headline figure on the right and, when
/// [help] is given, a "?" button after the title that opens the explanation
/// in a dialog — the long text stays out of the way until it is asked for.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.trailing,
    this.help,
  });

  final String title;
  final Widget? trailing;
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
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (help case final help?)
                      _HelpButton(title: title, text: help),
                  ],
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
