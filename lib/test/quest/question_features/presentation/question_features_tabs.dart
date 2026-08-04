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
import '../../comment/comment_widget/comment_widget.dart';
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
    // Enabled by flags; the konspekt tab is additionally dropped below unless
    // the category's konspekt actually has sections about this question.
    final enabled = _features.where(flags.isEnabled).toList();
    if (enabled.isEmpty) return const SizedBox.shrink();

    // Honour a deep-linked initial tab only when that feature is actually
    // visible to this user.
    final initial =
        (initialFeature != null && enabled.contains(initialFeature))
            ? initialFeature
            : null;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => QuestionFeaturesBloc(initial: initial)),
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
          final hasKonspekt =
              enabled.contains(AppFeature.categorySummaries) &&
              context
                  .watch<QuestionKonspektBloc>()
                  .state
                  .sections
                  .isNotEmpty;
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
class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.features, required this.selected});

  final List<AppFeature> features;
  final AppFeature selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Row(
        children: [
          for (final feature in features)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.read<QuestionFeaturesBloc>().add(
                    TabSelected(feature),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: feature == selected
                          ? scheme.secondaryContainer
                          : null,
                    ),
                    child: _TabLabel(
                      feature: feature,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: feature == selected
                            ? FontWeight.w600
                            : null,
                        color: feature == selected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
      case AppFeature.questionComments:
        return CommentWidget(questionId: questionId);
      case AppFeature.categorySummaries:
        return QuestionKonspektTab(categoryId: categoryId);
      case AppFeature.publicQuestionComments:
        return PublicCommentsWidget(
          questionId: questionId,
          threadId: commentThreadId,
        );
      case AppFeature.questionAnalysis:
        return QuestionAnalysisTab(questionId: questionId);
      default:
        return _ComingSoon(feature: feature);
    }
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
    _TabSpec(Icons.menu_book_outlined, LocaleKeys.questionTabs_explanation.tr()),
  AppFeature.categorySummaries =>
    _TabSpec(Icons.sticky_note_2_outlined, LocaleKeys.questionTabs_konspekt.tr()),
  AppFeature.publicQuestionComments =>
    _TabSpec(Icons.forum_outlined, LocaleKeys.questionTabs_discussion.tr()),
  AppFeature.questionAnalysis =>
    _TabSpec(Icons.insights_outlined, LocaleKeys.questionTabs_analysis.tr()),
  AppFeature.askAi =>
    _TabSpec(Icons.auto_awesome_outlined, LocaleKeys.questionTabs_askAi.tr()),
  _ => const _TabSpec(Icons.info_outline, ''),
};
