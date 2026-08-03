import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di.dart';
import '../../../../feature_flags/domain/app_feature.dart';
import '../../../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../../../public_comments/presentation/public_comments_widget.dart';
import '../../../../public_comments/state_management/comment_count_bloc.dart';
import '../../../../public_comments/state_management/comment_count_events.dart';
import '../../../../public_comments/state_management/comment_count_state.dart';
import '../../comment/comment_widget/comment_widget.dart';
import '../state_management/question_features_bloc.dart';
import '../state_management/question_features_events.dart';
import '../state_management/question_features_state.dart';

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
/// Only [AppFeature.questionComments] has real content (the expert comment for
/// the question, when the backend has one in `Ready` status); the other tabs
/// are placeholders until their features are built.
class QuestionFeaturesTabs extends StatelessWidget {
  const QuestionFeaturesTabs({super.key, required this.questionId});

  final int questionId;

  /// The per-question features, in the order their tabs appear.
  static const _features = <AppFeature>[
    AppFeature.questionComments,
    AppFeature.publicQuestionComments,
    AppFeature.questionAnalysis,
    AppFeature.askAi,
  ];

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlagsBloc>().state;
    final visible = _features.where(flags.isEnabled).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => QuestionFeaturesBloc()),
        // The tab badge only needs the scalar top-level count; kept apart from
        // the full comments Bloc scoped inside the discussion tab.
        if (visible.contains(AppFeature.publicQuestionComments))
          BlocProvider(
            create: (_) => getIt<CommentCountBloc>(param1: questionId)
              ..add(CommentCountRequested()),
          ),
      ],
      child: BlocBuilder<QuestionFeaturesBloc, QuestionFeaturesState>(
        builder: (context, state) {
          // Fall back to the first visible tab, and re-anchor if the previously
          // selected tab disappeared (e.g. the user logged out).
          final selected = (state.selected != null && visible.contains(state.selected)) ? state.selected! : visible.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _TabBar(features: visible, selected: selected),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _TabContent(feature: selected, questionId: questionId),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The tab bar itself. Holds a [TabController] (a ticker-based animation
/// controller, the sanctioned use of state in a widget) whose selection is
/// kept in lock-step with the [QuestionFeaturesBloc]: tapping a tab dispatches
/// [TabSelected], and an externally-changed [selected] (e.g. the visible tab
/// list shrank) is mirrored back onto the controller.
class _TabBar extends StatefulWidget {
  const _TabBar({required this.features, required this.selected});

  final List<AppFeature> features;
  final AppFeature selected;

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _newController();
  }

  TabController _newController() => TabController(
    length: widget.features.length,
    initialIndex: widget.features.indexOf(widget.selected).clamp(0, widget.features.length - 1),
    vsync: this,
  );

  @override
  void didUpdateWidget(covariant _TabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.features.length != widget.features.length) {
      // The set of visible tabs changed — the controller's length is fixed, so
      // rebuild it from scratch.
      _controller.dispose();
      _controller = _newController();
    } else {
      final index = widget.features.indexOf(widget.selected);
      if (index >= 0 && index != _controller.index) _controller.index = index;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: _controller,
      // Let the selection indicator span the full tab (≈1/n of the width)
      // rather than shrinking to the icon above it.
      indicatorSize: TabBarIndicatorSize.tab,
      tabs: widget.features.map((f) => _tabFor(context, f)).toList(),
      onTap: (index) => context.read<QuestionFeaturesBloc>().add(TabSelected(widget.features[index])),
    );
  }
}

Tab _tabFor(BuildContext context, AppFeature feature) {
  final spec = _specFor(feature);
  // The public-comments tab carries a badge with the number of top-level
  // comments (hidden when zero); the rest are plain icons.
  final Widget icon = feature == AppFeature.publicQuestionComments
      ? BlocBuilder<CommentCountBloc, CommentCountState>(
          builder: (context, state) => Badge.count(
            count: state.count,
            isLabelVisible: state.count > 0,
            child: Icon(spec.icon),
          ),
        )
      : Icon(spec.icon);
  // The tabs show only icons; the label is surfaced as a long-press tooltip.
  return Tab(icon: Tooltip(message: spec.label, child: icon));
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.feature, required this.questionId});

  final AppFeature feature;
  final int questionId;

  @override
  Widget build(BuildContext context) {
    switch (feature) {
      case AppFeature.questionComments:
        return CommentWidget(questionId: questionId);
      case AppFeature.publicQuestionComments:
        return PublicCommentsWidget(questionId: questionId);
      default:
        return _ComingSoon(feature: feature);
    }
  }
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
            'Ускоро доступно',
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
  AppFeature.questionComments => const _TabSpec(Icons.menu_book_outlined, 'Објашњење'),
  AppFeature.publicQuestionComments => const _TabSpec(Icons.forum_outlined, 'Дискусија'),
  AppFeature.questionAnalysis => const _TabSpec(Icons.insights_outlined, 'Анализа'),
  AppFeature.askAi => const _TabSpec(Icons.auto_awesome_outlined, 'Питај AI'),
  _ => const _TabSpec(Icons.info_outline, ''),
};
