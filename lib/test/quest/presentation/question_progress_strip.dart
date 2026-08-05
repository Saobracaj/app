import 'package:flutter/material.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

/// How one question of the current run has turned out so far.
enum QuestionStatus { unanswered, correct, wrong }

/// One segment of the strip: the question's number, its worth and whether it
/// has been answered correctly yet.
class QuestionNavigatorEntry {
  const QuestionNavigatorEntry({
    required this.questionId,
    required this.number,
    required this.points,
    required this.status,
  });

  final int questionId;

  /// 1-based position within this run, which is what the user is shown.
  final int number;
  final int points;
  final QuestionStatus status;
}

/// The segmented progress strip under the app bar: one segment per question,
/// colored by answer status, the current one accented.
///
/// It doubles as the run's navigator: a tap expands every segment into a
/// numbered chip of the same color (the strip reflows into as many rows as
/// needed); tapping a chip jumps to that question and collapses the strip
/// back, tapping between chips just collapses it. Hidden entirely for
/// single-question runs, where there is nothing to navigate.
///
/// The expanded flag is the sanctioned purely-visual local state; everything
/// it displays comes from [entries]. The widget must live *outside* any
/// per-question keyed subtree, or the collapse animation dies with the
/// element on every jump.
class QuestionProgressStrip extends StatefulWidget {
  const QuestionProgressStrip({
    super.key,
    required this.entries,
    required this.currentQuestionId,
    required this.onQuestionSelected,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;

  /// Called with the id of the chip the user tapped.
  final ValueChanged<int> onQuestionSelected;

  @override
  State<QuestionProgressStrip> createState() => _QuestionProgressStripState();
}

class _QuestionProgressStripState extends State<QuestionProgressStrip> {
  bool _expanded = false;

  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;
  static const _gap = 4.0;
  static const _chipWidth = 44.0;
  static const _chipHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    // A single question needs no progress bar and no navigation.
    if (widget.entries.length < 2) return const SizedBox.shrink();

    final quiz = Theme.of(context).quiz;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final n = widget.entries.length;
          // Collapsed segments split the row exactly; floor keeps rounding from
          // pushing the last segment onto a second line.
          final raw = ((constraints.maxWidth - _gap * (n - 1)) / n).floorToDouble();
          final collapsedWidth = raw < 2.0 ? 2.0 : raw;
          return GestureDetector(
            // Catches taps on the gaps between segments/chips too.
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Wrap(
              spacing: _gap,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in widget.entries)
                  _segment(entry, quiz, scheme, collapsedWidth),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _segment(
    QuestionNavigatorEntry entry,
    QuizColors quiz,
    ColorScheme scheme,
    double collapsedWidth,
  ) {
    final isCurrent = entry.questionId == widget.currentQuestionId;
    final (background, foreground) = isCurrent
        ? (scheme.primary, scheme.onPrimary)
        : switch (entry.status) {
            QuestionStatus.unanswered => (quiz.unanswered, quiz.onUnanswered),
            QuestionStatus.correct => (quiz.correct, quiz.onCorrect),
            QuestionStatus.wrong => (quiz.wrong, quiz.onWrong),
          };

    return GestureDetector(
      onTap: () {
        if (!_expanded) {
          setState(() => _expanded = true);
          return;
        }
        // Collapse first so the strip animates shut while the target question
        // is swapped in underneath.
        setState(() => _expanded = false);
        if (!isCurrent) widget.onQuestionSelected(entry.questionId);
      },
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        width: _expanded ? _chipWidth : collapsedWidth,
        height: _expanded ? _chipHeight : 6,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(_expanded ? _chipHeight / 2 : 2),
        ),
        // scaleDown keeps the number from overflowing mid-animation: it grows
        // out of the strip together with the chip.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedOpacity(
              duration: _duration,
              curve: _curve,
              opacity: _expanded ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${entry.number}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
