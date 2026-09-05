import 'package:flutter/material.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../feature_flags/domain/app_feature.dart';

/// Reports what of the feature panel under a question actually reached the
/// screen. Two events:
///
/// * `question_tab_shown` — the content of [tab] is on screen for
///   [questionId]; once per question per tab. Fires when the panel comes into
///   view with that tab selected and again whenever the selected tab changes
///   while the panel is visible. This is the "which explanations and konspekt
///   excerpts get read" signal, in both layouts.
/// * `question_tabs_viewed` — the operator's «домотал ли до вкладок»: once per
///   question, only when [underQuestion] (the phone layout, where the panel
///   sits below the answers; in the wide layout's side pane it is always on
///   screen and the question is moot).
///
/// StatefulWidget вместо Bloc сознательно: здесь нет ни состояния интерфейса,
/// ни бизнес-логики — только слушатель прокрутки и одноразовые флаги (тот же
/// класс исключения, что `_EnsureVisibleOnce` в question_features_tabs.dart).
class TabsSeenReporter extends StatefulWidget {
  const TabsSeenReporter({
    super.key,
    required this.questionId,
    required this.tab,
    this.underQuestion = true,
    required this.child,
  });

  final int questionId;

  /// The tab whose content the panel currently shows.
  final AppFeature tab;

  /// Phone layout: the panel is reached by scrolling past the answers.
  final bool underQuestion;

  final Widget child;

  @override
  State<TabsSeenReporter> createState() => _TabsSeenReporterState();
}

class _TabsSeenReporterState extends State<TabsSeenReporter> {
  ScrollPosition? _position;
  bool _tabsReported = false;
  final _shownTabs = <AppFeature>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_check);
      _position = position;
      _position?.addListener(_check);
    }
    // Вкладки могут быть видны и без прокрутки — короткий вопрос на высоком
    // экране; проверка после первого кадра, когда размеры уже известны.
    _checkAfterFrame();
  }

  @override
  void didUpdateWidget(TabsSeenReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new tab while the panel is on screen — the tab was switched by hand,
    // or the remembered one appeared once its content loaded.
    if (oldWidget.tab != widget.tab) _checkAfterFrame();
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _checkAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());

  bool get _done =>
      (_tabsReported || !widget.underQuestion) &&
      _shownTabs.contains(widget.tab);

  void _check() {
    if (_done || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final viewport = MediaQuery.sizeOf(context);
    final origin = box.localToGlobal(Offset.zero);
    // «Домотал» — когда от блока вкладок видно хотя бы заголовки-пилюли, а не
    // один пиксель верхней кромки.
    if (origin.dy >= viewport.height - 48) return;
    // Страницы вопросов лежат в листалке рядом: сосед, наполовину выехавший
    // при свайпе, ещё не показан — считается, когда панель в основном в кадре.
    final centerX = origin.dx + box.size.width / 2;
    if (centerX < 0 || centerX > viewport.width) return;
    if (widget.underQuestion && !_tabsReported) {
      _tabsReported = true;
      analytics.logQuestionTabsViewed(questionId: widget.questionId);
    }
    if (_shownTabs.add(widget.tab)) {
      analytics.logQuestionTabShown(
        tab: widget.tab.key,
        questionId: widget.questionId,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
