import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

const _duration = Duration(milliseconds: 280);
const _curve = Curves.easeOutCubic;

/// Зазор между сегментами по горизонтали и между строками чипов.
const _gap = 4.0;
const _runSpacing = 6.0;

const _chipWidth = 44.0;
const _chipHeight = 32.0;

/// Высота свёрнутой полоски.
const _barHeight = 6.0;

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
    this.position,
    this.scrollDepth = 0,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;

  /// Непрерывное положение прогона между вопросами — см.
  /// [QuestionProgressStrip.position].
  final ValueListenable<double>? position;

  /// На какой глубине вложенности приходит прокрутка тела вопроса. Ноль —
  /// когда [child] и есть прокручиваемое тело; единица — когда между ними
  /// стоит листалка вопросов (её собственная страница-прокрутка).
  final int scrollDepth;

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

  // Expanding takes a long deliberate pull — with a low threshold any careless
  // touch on the question opened the strip (task 1217292094173343).
  static const _expandThreshold = 72.0;
  static const _collapseThreshold = 12.0;

  bool _onScroll(ScrollNotification notification) {
    // A single-question run draws no strip, so there is nothing to toggle.
    if (widget.entries.length < 2) return false;
    // Scrollables nested in the body (the comments feed in the feature tabs)
    // are none of the strip's business — как и горизонтальная прокрутка самой
    // листалки вопросов, которая идёт с той же глубины, что и тело.
    if (notification.depth != widget.scrollDepth) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
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
          position: widget.position,
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
    this.position,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;

  /// Непрерывное положение прогона между вопросами (0 — первый вопрос, 1.5 —
  /// ровно между вторым и третьим): его отдаёт листалка, и по нему подсветка
  /// текущего сегмента переезжает за пальцем, а не перескакивает по факту
  /// смены вопроса. Без него подсветка стоит на [currentQuestionId].
  final ValueListenable<double>? position;

  /// Whether the segments are shown as numbered chips; owned by the caller so
  /// that scroll gestures can drive it too.
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// Called with the id of the chip the user tapped.
  final ValueChanged<int> onQuestionSelected;

  @override
  Widget build(BuildContext context) {
    // A single question needs no progress bar and no navigation.
    if (entries.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geometry = _StripGeometry(
            count: entries.length,
            width: constraints.maxWidth,
          );
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: expanded ? 1 : 0),
            duration: _duration,
            curve: _curve,
            builder: (context, t, _) {
              final listenable = position;
              if (listenable == null) {
                return _layer(context, geometry, t, _currentIndex.toDouble());
              }
              return ValueListenableBuilder<double>(
                valueListenable: listenable,
                builder: (context, at, _) => _layer(context, geometry, t, at),
              );
            },
          );
        },
      ),
    );
  }

  /// Индекс текущего вопроса — им подсветка стоит, когда листалка своего
  /// положения не сообщает.
  int get _currentIndex {
    final index = entries.indexWhere(
      (entry) => entry.questionId == currentQuestionId,
    );
    return index < 0 ? 0 : index;
  }

  /// Полоса на промежуточной фазе [t] (0 — свёрнута, 1 — раскрыта), с
  /// подсветкой в положении [at] (см. [position]).
  Widget _layer(
    BuildContext context,
    _StripGeometry geometry,
    double t,
    double at,
  ) {
    // A long run (145 questions in an exam category) folds into more chip
    // rows than the screen holds. Capping the navigator's height keeps the
    // question visible below it — so the usual ways to close it (scrolling
    // the body, tapping a gap) stay reachable — and the rows that don't fit
    // scroll inside the cap.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: SingleChildScrollView(
        primary: false,
        physics: expanded
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: GestureDetector(
          // Catches taps on the gaps between segments/chips too.
          behavior: HitTestBehavior.translucent,
          onTap: () => onExpandedChanged(!expanded),
          child: SizedBox(
            width: geometry.width,
            height: geometry.heightAt(t),
            child: Stack(
              children: [
                for (var i = 0; i < entries.length; i++)
                  Positioned.fromRect(
                    rect: geometry.rectAt(i, t),
                    child: _segment(context, entries[i], i, t, at),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    QuestionNavigatorEntry entry,
    int index,
    double t,
    double at,
  ) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    final scheme = theme.colorScheme;
    final isCurrent = entry.questionId == currentQuestionId;
    final (statusBackground, statusForeground) = switch (entry.status) {
      QuestionStatus.unanswered => (quiz.unanswered, quiz.onUnanswered),
      QuestionStatus.correct => (quiz.correct, quiz.onCorrect),
      QuestionStatus.wrong => (quiz.wrong, quiz.onWrong),
    };
    // Подсветка не перескакивает с сегмента на сегмент, а переезжает: на
    // полпути между вопросами оба соседа подсвечены наполовину, и полоса
    // идёт ровно за пальцем, который тянет страницу.
    final accent = (1 - (index - at).abs()).clamp(0.0, 1.0);
    final background = Color.lerp(statusBackground, scheme.primary, accent)!;
    final foreground = Color.lerp(statusForeground, scheme.onPrimary, accent)!;

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
      child: QuestionProgressSegment(
        color: background,
        radius: lerpDouble(2, _chipHeight / 2, t)!,
        // scaleDown keeps the number from overflowing mid-animation: it grows
        // out of the strip together with the chip.
        child: Opacity(
          opacity: t,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${entry.number}',
                  style: theme.textTheme.labelMedium?.copyWith(
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

/// Нарисованный сегмент полосы — свёрнутая полоска или раскрытый чип с номером.
///
/// Размер ему задаёт раскладка снаружи ([_StripGeometry]), поэтому виджет
/// только красит фон. Отдельный публичный класс нужен ещё и затем, чтобы тесты
/// могли измерить сегмент, не полагаясь на служебные обёртки.
class QuestionProgressSegment extends StatelessWidget {
  const QuestionProgressSegment({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Раскладка сегментов полосы: где стоит каждый из них в свёрнутом и в
/// раскрытом виде.
///
/// Обе раскладки считаются заранее, а анимация просто интерполирует
/// прямоугольники. Раньше вместо этого `Wrap` анимировал ширину детей и
/// перекладывал строки на каждом кадре: по мере роста чипов они по одному
/// перескакивали на следующую строку, строк становилось то больше, то меньше,
/// и раскрытие в несколько строк заметно дрожало (задача 1217520881378737).
/// Теперь каждый сегмент с первого же кадра едет в свою итоговую строку.
class _StripGeometry {
  factory _StripGeometry({required int count, required double width}) {
    // Collapsed segments split the row exactly; floor keeps rounding from
    // pushing the last segment onto a second line.
    var segment = ((width - _gap * (count - 1)) / count).floorToDouble();
    var gap = _gap;
    if (segment < _minSegmentWidth) {
      // Длинный прогон (145 вопросов экзаменационной категории) на телефоне не
      // помещается в строку с обычным зазором. Сегменты и так на пределе, так
      // что ужимается зазор: полоса остаётся одной строкой, а не обрезается по
      // краям и не разъезжается на несколько полос.
      segment = math.min(_minSegmentWidth, width / count);
      gap = count > 1
          ? math.max(0, (width - segment * count) / (count - 1))
          : 0;
    }
    return _StripGeometry._(
      count: count,
      width: width,
      collapsedWidth: segment,
      collapsedGap: gap,
      perRow: math.max(1, ((width + _gap) / (_chipWidth + _gap)).floor()),
    );
  }

  _StripGeometry._({
    required this.count,
    required this.width,
    required this.collapsedWidth,
    required this.collapsedGap,
    required this.perRow,
  }) : rows = (count / perRow).ceil();

  /// Минимальная ширина полоски свёрнутого сегмента.
  static const _minSegmentWidth = 2.0;

  final int count;
  final double width;

  /// Ширина сегмента и зазор между сегментами в свёрнутой полосе.
  final double collapsedWidth;
  final double collapsedGap;

  /// Сколько чипов встаёт в строку раскрытой полосы.
  final int perRow;

  final int rows;

  double get _expandedHeight =>
      rows * _chipHeight + (rows - 1) * _runSpacing;

  double heightAt(double t) => lerpDouble(_barHeight, _expandedHeight, t)!;

  /// Прямоугольник сегмента [index] на промежуточной фазе [t].
  ///
  /// По горизонтали сегмент приходит на место раньше, чем строки разъедутся по
  /// вертикали: при одинаковой скорости вся сетка едет наискось, и раскрытие
  /// читается как косой сдвиг вбок. На схлопывании та же расстановка фаз
  /// работает в обратную сторону — строки сперва сходятся, и только потом
  /// чипы сжимаются в полоску.
  Rect rectAt(int index, double t) {
    final tx = math.min(1.0, t / _horizontalPhase);
    final collapsed = _collapsed(index);
    final expanded = _expanded(index);
    return Rect.fromLTWH(
      lerpDouble(collapsed.left, expanded.left, tx)!,
      lerpDouble(collapsed.top, expanded.top, t)!,
      lerpDouble(collapsed.width, expanded.width, tx)!,
      lerpDouble(collapsed.height, expanded.height, t)!,
    );
  }

  /// Доля перехода, за которую сегмент проезжает свой путь по горизонтали.
  static const _horizontalPhase = 0.6;

  Rect _collapsed(int index) {
    // Остаток от округления ширины делится поровну по краям — так же, как это
    // делал WrapAlignment.center.
    final left =
        (width - (collapsedWidth * count + collapsedGap * (count - 1))) / 2;
    return Rect.fromLTWH(
      left + index * (collapsedWidth + collapsedGap),
      0,
      collapsedWidth,
      _barHeight,
    );
  }

  Rect _expanded(int index) {
    final row = index ~/ perRow;
    final column = index % perRow;
    // Последняя строка бывает неполной — её тоже центрируем.
    final inRow = math.min(perRow, count - row * perRow);
    final left = (width - (_chipWidth * inRow + _gap * (inRow - 1))) / 2;
    return Rect.fromLTWH(
      left + column * (_chipWidth + _gap),
      row * (_chipHeight + _runSpacing),
      _chipWidth,
      _chipHeight,
    );
  }
}
