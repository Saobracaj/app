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

/// The progress strip pinned under the app bar, with the scrollable body of the
/// question ([child]) below it.
///
/// The strip stays put while the body scrolls, and the body's own gestures
/// drive it: pulling down while the body is already at the top expands the
/// strip into the navigator, scrolling up collapses it back into the thin bar.
/// Tapping the strip still toggles it by hand.
///
/// The expanded flag is the sanctioned purely-visual local state; everything it
/// displays comes from [entries]. The widget must live *outside* any
/// per-question keyed subtree, or the collapse animation dies with the element
/// on every jump.
class QuestionProgressHeader extends StatefulWidget {
  const QuestionProgressHeader({
    super.key,
    required this.entries,
    required this.currentQuestionId,
    required this.onQuestionSelected,
    required this.child,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;

  /// Called with the id of the chip the user tapped.
  final ValueChanged<int> onQuestionSelected;

  /// The scrolling body of the question; its scroll gestures expand and
  /// collapse the strip above it.
  final Widget child;

  @override
  State<QuestionProgressHeader> createState() => _QuestionProgressHeaderState();
}

class _QuestionProgressHeaderState extends State<QuestionProgressHeader> {
  bool _expanded = false;

  /// Travel accumulated by the current gesture in each direction, so that the
  /// strip answers a deliberate pull instead of flickering on every wobble of
  /// the finger.
  double _pullDown = 0;
  double _pushUp = 0;

  static const _expandThreshold = 24.0;
  static const _collapseThreshold = 12.0;

  bool _onScroll(ScrollNotification notification) {
    // A single-question run draws no strip, so there is nothing to toggle.
    if (widget.entries.length < 2) return false;
    // Scrollables nested in the body (the comments feed in the feature tabs)
    // are none of the strip's business.
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _pullDown = 0;
      _pushUp = 0;
      return false;
    }

    // Only what the finger does counts. Ballistic frames — the iOS spring
    // snapping an overscroll back, the tail of a fling — would otherwise undo
    // the very gesture that just expanded the strip.
    final double delta;
    if (notification is OverscrollNotification) {
      // Clamping physics (Android) reports a pull past either edge here, since
      // the offset itself cannot move any further.
      if (notification.dragDetails == null) return false;
      delta = notification.overscroll;
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) return false;
      delta = notification.scrollDelta ?? 0;
      // Downward travel counts as a pull only at the very top of the body —
      // in the middle of the list it is ordinary scrolling back, which must
      // not pop the navigator open under the user's finger.
      if (delta < 0 &&
          notification.metrics.pixels > notification.metrics.minScrollExtent) {
        return false;
      }
    } else {
      return false;
    }

    if (delta < 0) {
      _pushUp = 0;
      _pullDown -= delta;
      if (!_expanded && _pullDown >= _expandThreshold) {
        setState(() => _expanded = true);
      }
    } else if (delta > 0) {
      _pullDown = 0;
      _pushUp += delta;
      if (_expanded && _pushUp >= _collapseThreshold) {
        setState(() => _expanded = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        QuestionProgressStrip(
          entries: widget.entries,
          currentQuestionId: widget.currentQuestionId,
          expanded: _expanded,
          onExpandedChanged: (value) => setState(() => _expanded = value),
          onQuestionSelected: widget.onQuestionSelected,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// The segmented progress strip itself: one segment per question, colored by
/// answer status, the current one accented.
///
/// It doubles as the run's navigator: while [expanded] every segment grows into
/// a numbered chip of the same color (the strip reflows into as many rows as
/// needed); tapping a chip jumps to that question and collapses the strip back,
/// tapping between chips just collapses it. Hidden entirely for single-question
/// runs, where there is nothing to navigate.
class QuestionProgressStrip extends StatelessWidget {
  const QuestionProgressStrip({
    super.key,
    required this.entries,
    required this.currentQuestionId,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onQuestionSelected,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;

  /// Whether the segments are shown as numbered chips; owned by the caller so
  /// that scroll gestures can drive it too.
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// Called with the id of the chip the user tapped.
  final ValueChanged<int> onQuestionSelected;

  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;
  static const _gap = 4.0;
  static const _chipWidth = 44.0;
  static const _chipHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    // A single question needs no progress bar and no navigation.
    if (entries.length < 2) return const SizedBox.shrink();

    final quiz = Theme.of(context).quiz;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final n = entries.length;
          // Collapsed segments split the row exactly; floor keeps rounding from
          // pushing the last segment onto a second line.
          final raw = ((constraints.maxWidth - _gap * (n - 1)) / n)
              .floorToDouble();
          final collapsedWidth = raw < 2.0 ? 2.0 : raw;
          return GestureDetector(
            // Catches taps on the gaps between segments/chips too.
            behavior: HitTestBehavior.translucent,
            onTap: () => onExpandedChanged(!expanded),
            child: Wrap(
              spacing: _gap,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in entries)
                  _segment(context, entry, quiz, scheme, collapsedWidth),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    QuestionNavigatorEntry entry,
    QuizColors quiz,
    ColorScheme scheme,
    double collapsedWidth,
  ) {
    final isCurrent = entry.questionId == currentQuestionId;
    final (background, foreground) = isCurrent
        ? (scheme.primary, scheme.onPrimary)
        : switch (entry.status) {
            QuestionStatus.unanswered => (quiz.unanswered, quiz.onUnanswered),
            QuestionStatus.correct => (quiz.correct, quiz.onCorrect),
            QuestionStatus.wrong => (quiz.wrong, quiz.onWrong),
          };

    return GestureDetector(
      onTap: () {
        if (!expanded) {
          onExpandedChanged(true);
          return;
        }
        // Collapse first so the strip animates shut while the target question
        // is swapped in underneath.
        onExpandedChanged(false);
        if (!isCurrent) onQuestionSelected(entry.questionId);
      },
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        width: expanded ? _chipWidth : collapsedWidth,
        height: expanded ? _chipHeight : 6,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(expanded ? _chipHeight / 2 : 2),
        ),
        // scaleDown keeps the number from overflowing mid-animation: it grows
        // out of the strip together with the chip.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedOpacity(
              duration: _duration,
              curve: _curve,
              opacity: expanded ? 1 : 0,
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
