import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di.dart';
import '../../../../feature_flags/domain/app_feature.dart';
import '../../../../generated/locale_keys.g.dart';
import '../../../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../../../public_comments/presentation/public_comments_widget.dart';
import '../../../../public_comments/state_management/comment_count_bloc.dart';
import '../../../../public_comments/state_management/comment_count_events.dart';
import '../../../../public_comments/state_management/comment_count_state.dart';
import '../../../../question_feedback/domain/question_feedback_source.dart';
import '../../../../question_feedback/presentation/report_problem_button.dart';
import '../../comment/comment_widget/comment_widget.dart';
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
/// The content of the selected tab is rendered as a normal child of the
/// surrounding scroll view (no [TabBarView]), so it grows to fit its content
/// and scrolls with the rest of the question instead of needing a bounded box.
///
/// The chrome is adaptive: with a single visible section the tab row collapses
/// into a plain header.
class QuestionFeaturesTabs extends StatelessWidget {
  const QuestionFeaturesTabs({
    super.key,
    required this.questionId,
    required this.categoryId,
    this.initialFeature,
    this.commentThreadId,
    this.autoScroll = false,
  });

  final int questionId;

  /// The category the question belongs to — the konspekt tab excerpts that
  /// category's konspekt.
  final String categoryId;

  /// Deep-link support: the tab to pre-select (e.g. the discussion), the thread
  /// to expand inside it, and whether to scroll this panel into view on open.
  final AppFeature? initialFeature;
  final String? commentThreadId;
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
    // The konspekt tab is additionally dropped below unless the category's
    // konspekt actually has sections about this question.
    final enabled = _features
        .where((f) => flags.isEnabledForCategory(f, categoryId))
        .toList();
    if (enabled.isEmpty) return const SizedBox.shrink();

    // Honour a deep-linked initial tab only when that feature is actually
    // visible to this user.
    final initial =
        (initialFeature != null && enabled.contains(initialFeature))
            ? initialFeature
            : null;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<QuestionFeaturesBloc>(param1: initial),
        ),
        // The tab badge only needs the scalar top-level count; kept apart from
        // the full comments Bloc scoped inside the discussion tab.
        if (enabled.contains(AppFeature.publicQuestionComments))
          BlocProvider(
            create: (_) => getIt<CommentCountBloc>(param1: questionId)
              ..add(CommentCountRequested()),
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
          final selected = (state.selected != null && visible.contains(state.selected)) ? state.selected! : visible.first;
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _TabContent(
                      feature: selected,
                      questionId: questionId,
                      categoryId: categoryId,
                      commentThreadId: commentThreadId,
                    ),
                  ),
                ],
              ),
            ),
          );
          // On a deep link into the discussion, scroll this panel into view once
          // it is laid out.
          return autoScroll ? _EnsureVisibleOnce(child: card) : card;
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
      icon = BlocBuilder<CommentCountBloc, CommentCountState>(
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
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
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
    return BlocBuilder<CommentCountBloc, CommentCountState>(
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
    this.commentThreadId,
  });

  final AppFeature feature;
  final int questionId;
  final String categoryId;
  final String? commentThreadId;

  @override
  Widget build(BuildContext context) {
    switch (feature) {
      // Объяснение, конспект и обсуждение — вкладки с чужим содержимым, в
      // котором пользователю есть на что пожаловаться, поэтому кнопка «Сообщить
      // об ошибке» живёт под ними (и только под ними).
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
          child: QuestionKonspektTab(categoryId: categoryId),
        );
      case AppFeature.publicQuestionComments:
        return _WithReportButton(
          questionId: questionId,
          source: QuestionFeedbackSource.discussion,
          child: PublicCommentsWidget(
            questionId: questionId,
            threadId: commentThreadId,
          ),
        );
      case AppFeature.questionAnalysis:
        return QuestionAnalysisTab(questionId: questionId);
      // Вкладка — это только чат: разбор вопроса и выдержки из закона уже есть
      // на вкладках «Объяснение» и «Конспект», дублировать их здесь незачем.
      // Ответы AI — сгенерированный контент, в котором бывает на что
      // пожаловаться, поэтому кнопка «Сообщить об ошибке» есть и здесь.
      case AppFeature.askAi:
        return _WithReportButton(
          questionId: questionId,
          source: QuestionFeedbackSource.askAi,
          child: AskAiChatSection(questionId: questionId),
        );
      default:
        return _ComingSoon(feature: feature);
    }
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
        ReportProblemButton(questionId: questionId, source: source),
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
      Scrollable.ensureVisible(
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
          Text(spec.label, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.questionTabs_comingSoon.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
  AppFeature.questionComments =>
    _TabSpec(Icons.sticky_note_2_outlined, LocaleKeys.questionTabs_explanation.tr()),
  AppFeature.categorySummaries =>
    _TabSpec(Icons.menu_book_outlined, LocaleKeys.questionTabs_konspekt.tr()),
  AppFeature.publicQuestionComments =>
    _TabSpec(Icons.forum_outlined, LocaleKeys.questionTabs_discussion.tr()),
  AppFeature.questionAnalysis =>
    _TabSpec(Icons.insights_outlined, LocaleKeys.questionTabs_analysis.tr()),
  AppFeature.askAi =>
    _TabSpec(Icons.auto_awesome_outlined, LocaleKeys.questionTabs_askAi.tr()),
  _ => const _TabSpec(Icons.info_outline, ''),
};
