import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di.dart';
import '../../../../core/vertical_scroll.dart';
import '../../../../feature_flags/domain/app_feature.dart';
import '../../../../generated/locale_keys.g.dart';
import '../../../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../../../chat/presentation/question_chat_section.dart';
import '../../../../chat/state_management/question_chat_count_bloc.dart';
import '../../../../chat/state_management/question_chat_count_events.dart';
import '../../../../chat/state_management/question_chat_count_state.dart';
import '../../../../question_feedback/domain/question_feedback_source.dart';
import '../../../../question_feedback/domain/question_feedback_target.dart';
import '../../../../question_feedback/presentation/report_problem_button.dart';
import '../../../../subscription/presentation/paywall.dart';
import '../../comment/comment_widget/comment_widget.dart';
import '../../presentation/tabs_seen_reporter.dart';
import '../ask_ai/presentation/ask_ai_chat_section.dart';
import '../state_management/question_features_bloc.dart';
import '../state_management/question_features_events.dart';
import '../state_management/question_features_state.dart';
import '../state_management/question_konspekt_bloc.dart';
import 'question_analysis_tab.dart';
import 'question_konspekt_tab.dart';

/// Tabbed panel shown under a question (only on the *questions* flow, not
/// practice) exposing the per-question features. Each tab is gated by its
/// [AppFeature] flag — including premium flags resolved from the backend via
/// [FeatureFlagsBloc] — so the bar renders only the tabs the current user has
/// access to, and hides entirely when none are available.
///
/// The tabs' content lives in a [PageView] ([_TabPages]): a tap slides the
/// pages over, a horizontal swipe on the content switches the tab. The pager
/// sizes itself to the open tab, so the panel still grows to fit its content
/// and scrolls with the rest of the question instead of needing a bounded box
/// (which is why it is not a [TabBarView]).
///
/// The chrome is adaptive: with a single visible section the tab row collapses
/// into a plain header.
class QuestionFeaturesTabs extends StatelessWidget {
  const QuestionFeaturesTabs({
    super.key,
    required this.questionId,
    required this.categoryId,
    this.initialFeature,
    this.chatMessageId,
    this.autoScroll = false,
    this.underQuestion = true,
  });

  final int questionId;

  /// Where the panel sits: under the answers, reached by scrolling (the phone
  /// layout, default), or in the wide layout's side pane that is on screen
  /// from the moment the answers are revealed. Analytics context only — see
  /// [TabsSeenReporter].
  final bool underQuestion;

  /// The category the question belongs to — the konspekt tab excerpts that
  /// category's konspekt.
  final String categoryId;

  /// Deep-link support: the tab to pre-select (e.g. the discussion), the chat
  /// message to reveal inside it, and whether to scroll this panel into view on
  /// open.
  final AppFeature? initialFeature;
  final String? chatMessageId;
  final bool autoScroll;

  /// The per-question features, in the order their tabs appear.
  static const _features = <AppFeature>[
    AppFeature.questionComments,
    AppFeature.categorySummaries,
    AppFeature.publicQuestionComments,
    AppFeature.questionAnalysis,
    AppFeature.askAi,
  ];

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlagsBloc>().state;
    // Enabled by flags *for this question's category* — in the free categories
    // (25/26/28) the content tabs are open to everybody, the AI chat is not.
    // A premium tab the reader has *not* switched off stays on screen when it
    // is merely locked: it shows a preview and the offer of the pass — the
    // paywall lives at the point of pain, not on a screen of its own. The
    // konspekt tab is additionally dropped below unless the category's
    // konspekt actually has sections about this question.
    final locked = {
      for (final f in _features)
        if (flags.isLockedForCategory(f, categoryId)) f,
    };
    final enabled = _features
        .where(
          (f) =>
              flags.isEnabledForCategory(f, categoryId) || locked.contains(f),
        )
        .toList();
    if (enabled.isEmpty) return const SizedBox.shrink();

    // Honour a deep-linked initial tab only when that feature is actually
    // visible to this user.
    final initial = (initialFeature != null && enabled.contains(initialFeature))
        ? initialFeature
        : null;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<QuestionFeaturesBloc>(param1: initial, param2: questionId),
        ),
        // Значку нужен один скаляр, поэтому он читается отдельно от чата,
        // живущего внутри самой вкладки.
        if (enabled.contains(AppFeature.publicQuestionComments))
          BlocProvider(
            create: (_) =>
                getIt<QuestionChatCountBloc>(param1: questionId)
                  ..add(QuestionChatCountRequested()),
          ),
        // Loads the excerpts up front: the tab is only shown once they exist.
        if (enabled.contains(AppFeature.categorySummaries))
          BlocProvider(
            create: (_) => getIt<QuestionKonspektBloc>(
              param1: questionId,
              param2: categoryId,
            ),
          ),
      ],
      child: BlocBuilder<QuestionFeaturesBloc, QuestionFeaturesState>(
        builder: (context, state) {
          // The konspekt tab appears once there is something to show — or once
          // the excerpts failed to load, so the failure is visible and
          // retryable instead of looking like a question without notes.
          final konspekt = enabled.contains(AppFeature.categorySummaries)
              ? context.watch<QuestionKonspektBloc>().state
              : null;
          final hasKonspekt =
              konspekt != null &&
              (konspekt.sections.isNotEmpty || konspekt.failed);
          final visible = [
            for (final feature in enabled)
              if (feature != AppFeature.categorySummaries || hasKonspekt)
                feature,
          ];
          if (visible.isEmpty) return const SizedBox.shrink();
          // Fall back to the first visible tab, and re-anchor if the previously
          // selected tab disappeared (e.g. the user logged out).
          final selected =
              (state.selected != null && visible.contains(state.selected))
              ? state.selected!
              : visible.first;
          final card = Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (visible.length == 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: _TabLabel(
                        feature: visible.single,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    )
                  else
                    _PillTabs(features: visible, selected: selected),
                  _TabPages(
                    features: visible,
                    selected: selected,
                    pageBuilder: (feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _TabContent(
                        feature: feature,
                        questionId: questionId,
                        categoryId: categoryId,
                        chatMessageId: chatMessageId,
                        locked: locked.contains(feature),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          // What of the panel reached the screen — «домотал» and which tab's
          // content was actually shown for this question.
          final reported = TabsSeenReporter(
            key: ValueKey('tabs-seen-$questionId'),
            questionId: questionId,
            tab: selected,
            underQuestion: underQuestion,
            child: card,
          );
          // On a deep link into the discussion, scroll this panel into view once
          // it is laid out.
          return autoScroll ? _EnsureVisibleOnce(child: reported) : reported;
        },
      ),
    );
  }
}

/// The stateless pill-style tab row, driven entirely by [QuestionFeaturesBloc].
///
/// Five text labels never fit one row, so the tabs are icon-first: an
/// unselected tab is just its icon (with a tooltip, and an unread-style count
/// badge on the discussion), while the selected tab expands into an
/// icon + label pill. The label growing/shrinking is animated, so selection
/// slides the row rather than snapping it.
class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.features, required this.selected});

  final List<AppFeature> features;
  final AppFeature selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Row(
        children: [
          for (final feature in features)
            // Only the expanded pill may shrink (its label ellipsizes); the
            // icon-only pills keep their natural size.
            if (feature == selected)
              Flexible(child: _TabPill(feature: feature, selected: true))
            else
              _TabPill(feature: feature, selected: false),
        ],
      ),
    );
  }
}

/// One tab of the row: icon-only when idle, icon + label when selected.
class _TabPill extends StatelessWidget {
  const _TabPill({required this.feature, required this.selected});

  final AppFeature feature;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = _specFor(feature);
    final color = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface.withValues(alpha: 0.6);

    // Separate variables: the closure below must capture the plain icon, not
    // the wrapped widget it is being assigned to (that reads the variable at
    // call time and recurses into itself).
    final baseIcon = Icon(spec.icon, size: 18, color: color);
    Widget icon = baseIcon;
    // The collapsed discussion tab still shows how much is inside it.
    if (feature == AppFeature.publicQuestionComments && !selected) {
      icon = BlocBuilder<QuestionChatCountBloc, QuestionChatCountState>(
        builder: (context, state) => Badge.count(
          count: state.count,
          isLabelVisible: state.count > 0,
          child: baseIcon,
        ),
      );
    }

    final pill = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () =>
          context.read<QuestionFeaturesBloc>().add(TabSelected(feature)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? scheme.secondaryContainer : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            Flexible(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: _TabLabel(
                          feature: feature,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      // The icon alone doesn't say what the tab is — the tooltip does.
      child: selected ? pill : Tooltip(message: spec.label, child: pill),
    );
  }
}

/// A tab's text label; the discussion one carries the top-level comment count
/// inline ("Дискусија · 4") instead of a badge.
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.feature, this.style});

  final AppFeature feature;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final label = _specFor(feature).label;
    if (feature != AppFeature.publicQuestionComments) {
      return Text(
        label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return BlocBuilder<QuestionChatCountBloc, QuestionChatCountState>(
      builder: (context, state) => Text(
        state.count > 0 ? '$label · ${state.count}' : label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.feature,
    required this.questionId,
    required this.categoryId,
    this.chatMessageId,
    this.locked = false,
  });

  final AppFeature feature;
  final int questionId;
  final String categoryId;
  final String? chatMessageId;

  /// The feature is behind the pass for this question. The explanation and
  /// the konspekt still load — the backend answers with a preview — while the
  /// analysis and the AI chat have no preview and show the offer alone.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (locked && feature == AppFeature.questionAnalysis) {
      return LockedContentCard(
        source: PaywallSource.analysis,
        questionId: questionId,
        categoryId: categoryId,
        title: LocaleKeys.subscription_lockedAnalysisTitle.tr(),
        body: LocaleKeys.subscription_lockedAnalysisBody.tr(),
      );
    }
    if (locked && feature == AppFeature.askAi) {
      return LockedContentCard(
        source: PaywallSource.askAi,
        questionId: questionId,
        categoryId: categoryId,
        title: LocaleKeys.subscription_lockedAskAiTitle.tr(),
        body: LocaleKeys.subscription_lockedAskAiBody.tr(),
      );
    }
    switch (feature) {
      // Объяснение и конспект — вкладки с редакторским контентом, в котором
      // пользователю есть на что пожаловаться, поэтому кнопка «Сообщить об
      // ошибке» живёт под ними. Обсуждению она не нужна: на сообщение чата
      // жалуются из его собственного меню.
      case AppFeature.questionComments:
        return _WithReportButton(
          questionId: questionId,
          source: QuestionFeedbackSource.explanation,
          child: CommentWidget(questionId: questionId),
        );
      case AppFeature.categorySummaries:
        return _WithReportButton(
          questionId: questionId,
          source: QuestionFeedbackSource.summary,
          child: QuestionKonspektTab(
            categoryId: categoryId,
            questionId: questionId,
            locked: locked,
          ),
        );
      // Обсуждение вопроса — обычный чат приложения, только перевёрнутый:
      // поле ввода сверху, под ним свежее сообщение, дальше в прошлое.
      case AppFeature.publicQuestionComments:
        return QuestionChatSection(
          questionId: questionId,
          messageId: chatMessageId,
        );
      case AppFeature.questionAnalysis:
        return QuestionAnalysisTab(questionId: questionId);
      // Вкладка — это только чат: разбор вопроса и выдержки из закона уже есть
      // на вкладках «Объяснение» и «Конспект», дублировать их здесь незачем.
      case AppFeature.askAi:
        return AskAiChatSection(questionId: questionId);
      default:
        return _ComingSoon(feature: feature);
    }
  }
}

/// Страницы вкладок — [PageView], который сам подстраивает высоту под
/// содержимое открытой вкладки: панель по-прежнему растёт вместе с ним и
/// прокручивается вместе с вопросом, а не живёт в коробке заданной высоты
/// (без неё [TabBarView] не работает).
///
/// Кто хозяин выбранной вкладки — по-прежнему [QuestionFeaturesBloc]:
/// [selected] приходит снаружи, и расхождение с реальной страницей
/// выправляется анимацией ([PageController.animateToPage]) — так переключают
/// пилюли. Обратный путь — свайп: палец перевёл страницу, блоку сообщают
/// [TabSelected]. Страницы, которые программная анимация проходит транзитом,
/// не докладываются — блок принял бы доклад за новую цель (та же логика, что в
/// `QuestionPager`). Сменился состав вкладок (подъехал конспект, читатель
/// вышел из аккаунта) — номера страниц поехали, и листалка переставляется на
/// выбранную без анимации.
///
/// Высота: каждая страница лежит в [OverflowBox] без ограничения снизу и
/// сообщает свой размер ([_MeasuredPage]); листалка получает высоту текущей
/// страницы, а во время протяжки — промежуточную между соседями, так что низ
/// карточки едет за пальцем. Соседние страницы заранее не строятся (у
/// [PageView] нулевой cacheExtent), поэтому содержимое вкладки, как и раньше,
/// грузится только когда её открыли.
///
/// StatefulWidget сознательно: здесь нет ни состояния интерфейса, ни
/// бизнес-логики — только контроллер листалки и измеренные высоты (то же
/// исключение, что у [_EnsureVisibleOnce]).
class _TabPages extends StatefulWidget {
  const _TabPages({
    required this.features,
    required this.selected,
    required this.pageBuilder,
  });

  /// Вкладки в порядке страниц.
  final List<AppFeature> features;

  /// Открытая вкладка по мнению блока.
  final AppFeature selected;

  final Widget Function(AppFeature feature) pageBuilder;

  /// Длительность и кривая программного перехода — те же, что у листалки
  /// вопросов, чтобы движения экрана не спорили друг с другом.
  static const Duration duration = Duration(milliseconds: 280);
  static const Curve curve = Curves.easeOutCubic;

  @override
  State<_TabPages> createState() => _TabPagesState();
}

class _TabPagesState extends State<_TabPages> {
  late final PageController _controller = PageController(initialPage: _index);

  /// Измеренные высоты страниц — по вкладке, а не по номеру: номера ездят
  /// вместе с составом вкладок.
  final _heights = <AppFeature, double>{};

  /// Ведёт ли текущую прокрутку палец — программный переход блоку не
  /// докладывается (он его и заказал).
  bool _dragged = false;

  /// Последняя выданная высота: пока нужную страницу не измерили, держим её,
  /// чтобы карточка не схлопывалась на кадр.
  double _height = 0;

  int get _index => widget.features.indexOf(widget.selected);

  double? get _page {
    if (!_controller.hasClients) return null;
    final position = _controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) return null;
    return _controller.page;
  }

  @override
  void didUpdateWidget(_TabPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = !listEquals(oldWidget.features, widget.features);
    if (!moved && oldWidget.selected == widget.selected) return;
    if (!_controller.hasClients) {
      // Вкладка сменилась раньше, чем страницы разложились: анимировать
      // нечего, переставляем первым же кадром.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        if (_page?.round() == _index) return;
        _controller.jumpToPage(_index);
      });
      return;
    }
    // Страница уже там — так приходит вкладка, которую сам палец и перевёл.
    if (_page?.round() == _index) return;
    if (moved) {
      // Не [PageController.jumpToPage]: новая страница может лежать за
      // прежним краем прокрутки (конспект встал перед открытой последней
      // вкладкой), и прыжок туда отпружинил бы назад по старому extent ещё до
      // раскладки. Пиксели ставятся напрямую, а раскладка, которая идёт
      // следом за этой перестройкой, уже знает новый состав страниц.
      final position = _controller.position;
      if (position.hasViewportDimension && position.hasPixels) {
        position.correctPixels(
          _index * position.viewportDimension * _controller.viewportFraction,
        );
      } else {
        _controller.jumpToPage(_index);
      }
      return;
    }
    _controller.animateToPage(
      _index,
      duration: _TabPages.duration,
      curve: _TabPages.curve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= widget.features.length) return;
    final feature = widget.features[index];
    if (feature == widget.selected) return;
    context.read<QuestionFeaturesBloc>().add(TabSelected(feature));
  }

  bool _onScroll(ScrollNotification notification) {
    // Прокрутка внутри страницы — не наше дело.
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _dragged = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      _dragged = false;
      // Прокрутка встала не на вкладке блока — доложить: так в блок попадает
      // исход перехода, о котором [PageView.onPageChanged] промолчал
      // (трекпад, оборванная на полпути анимация).
      final settled = _page?.round();
      if (settled != null && settled != _index) _select(settled);
    }
    return false;
  }

  void _onMeasured(AppFeature feature, double height) {
    if (!mounted || _heights[feature] == height) return;
    setState(() => _heights[feature] = height);
  }

  /// Высота листалки в положении [page]: между соседями — промежуточная,
  /// неизмеренный сосед берёт высоту измеренного.
  double _heightAt(double page) {
    double? at(int index) => index >= 0 && index < widget.features.length
        ? _heights[widget.features[index]]
        : null;
    final lower = page.floor();
    final upper = page.ceil();
    final from = at(lower);
    final to = at(upper);
    final height = switch ((from, to)) {
      (null, null) => null,
      (final a?, null) => a,
      (null, final b?) => b,
      (final a?, final b?) => lerpDouble(a, b, page - lower),
    };
    if (height != null) _height = height;
    return _height;
  }

  @override
  Widget build(BuildContext context) {
    final features = widget.features;
    final pager = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: PageView.custom(
        controller: _controller,
        onPageChanged: (index) {
          // Докладывать блоку — только страницы, переведённые пальцем (и прямо
          // под ним, не дожидаясь остановки): пилюля подсвечивается в такт
          // свайпу.
          if (_dragged) _select(index);
        },
        childrenDelegate: SliverChildBuilderDelegate(
          (context, index) {
            final feature = features[index];
            return KeyedSubtree(
              key: ValueKey(feature),
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: _MeasuredPage(
                  onHeight: (height) => _onMeasured(feature, height),
                  child: widget.pageBuilder(feature),
                ),
              ),
            );
          },
          childCount: features.length,
          // Страница узнаётся по вкладке, а не по номеру, — открытая вкладка
          // переживает сдвиг номеров без пересборки.
          findChildIndexCallback: (key) {
            final index = features.indexOf((key as ValueKey<AppFeature>).value);
            return index < 0 ? null : index;
          },
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          SizedBox(height: _heightAt(_page ?? _index.toDouble()), child: child),
      child: pager,
    );
  }
}

/// Сообщает высоту своего ребёнка после раскладки — [_TabPages] подгоняет по
/// ней высоту листалки. Сообщение уходит после кадра: `setState` во время
/// раскладки запрещён.
class _MeasuredPage extends SingleChildRenderObjectWidget {
  const _MeasuredPage({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredPage(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredPage renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderMeasuredPage extends RenderProxyBox {
  _RenderMeasuredPage(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_reported == height) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}

/// Содержимое вкладки с кнопкой «Сообщить об ошибке» под ним.
class _WithReportButton extends StatelessWidget {
  const _WithReportButton({
    required this.questionId,
    required this.source,
    required this.child,
  });

  final int questionId;
  final QuestionFeedbackSource source;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        ReportProblemButton(
          target: QuestionFeedbackTarget.question(questionId),
          source: source,
        ),
      ],
    );
  }
}

/// Scrolls its [child] into view exactly once after the first layout — used to
/// bring the discussion panel on screen when arriving via a deep link.
class _EnsureVisibleOnce extends StatefulWidget {
  const _EnsureVisibleOnce({required this.child});

  final Widget child;

  @override
  State<_EnsureVisibleOnce> createState() => _EnsureVisibleOnceState();
}

class _EnsureVisibleOnceState extends State<_EnsureVisibleOnce> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_done || !mounted) return;
      _done = true;
      // Только вертикальная прокрутка: панель лежит внутри листалки вопросов,
      // и [Scrollable.ensureVisible] прокрутил бы и её.
      revealVertically(
        context,
        duration: const Duration(milliseconds: 400),
        alignment: 0.1,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Placeholder body for tabs whose feature is not implemented yet.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.feature});

  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = _specFor(feature);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Icon(spec.icon, size: 40, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            spec.label,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.questionTabs_comingSoon.tr(),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Icon + label for a feature tab.
class _TabSpec {
  const _TabSpec(this.icon, this.label);

  final IconData icon;
  final String label;
}

_TabSpec _specFor(AppFeature feature) => switch (feature) {
  AppFeature.questionComments => _TabSpec(
    Icons.sticky_note_2_outlined,
    LocaleKeys.questionTabs_explanation.tr(),
  ),
  AppFeature.categorySummaries => _TabSpec(
    Icons.menu_book_outlined,
    LocaleKeys.questionTabs_konspekt.tr(),
  ),
  AppFeature.publicQuestionComments => _TabSpec(
    Icons.forum_outlined,
    LocaleKeys.questionTabs_discussion.tr(),
  ),
  AppFeature.questionAnalysis => _TabSpec(
    Icons.insights_outlined,
    LocaleKeys.questionTabs_analysis.tr(),
  ),
  AppFeature.askAi => _TabSpec(
    Icons.auto_awesome_outlined,
    LocaleKeys.questionTabs_askAi.tr(),
  ),
  _ => const _TabSpec(Icons.info_outline, ''),
};
