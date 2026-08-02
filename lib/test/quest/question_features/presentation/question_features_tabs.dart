import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../feature_flags/domain/app_feature.dart';
import '../../../../feature_flags/state_management/feature_flags_bloc.dart';
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

    return BlocProvider(
      create: (_) => QuestionFeaturesBloc(),
      child: BlocBuilder<QuestionFeaturesBloc, QuestionFeaturesState>(
        builder: (context, state) {
          // Fall back to the first visible tab, and re-anchor if the previously
          // selected tab disappeared (e.g. the user logged out).
          final selected =
              (state.selected != null && visible.contains(state.selected))
                  ? state.selected!
                  : visible.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Divider(height: 1),
              _TabBar(features: visible, selected: selected),
              const Divider(height: 1),
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

class _TabBar extends StatelessWidget {
  const _TabBar({required this.features, required this.selected});

  final List<AppFeature> features;
  final AppFeature selected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _TabButton(
                feature: feature,
                selected: feature == selected,
                onTap:
                    () => context.read<QuestionFeaturesBloc>().add(
                      TabSelected(feature),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.feature,
    required this.selected,
    required this.onTap,
  });

  final AppFeature feature;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = _specFor(feature);
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                spec.label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          Text(
            spec.label,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Ускоро доступно',
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
  AppFeature.questionComments => const _TabSpec(
    Icons.menu_book_outlined,
    'Објашњење',
  ),
  AppFeature.publicQuestionComments => const _TabSpec(
    Icons.forum_outlined,
    'Дискусија',
  ),
  AppFeature.questionAnalysis => const _TabSpec(
    Icons.insights_outlined,
    'Анализа',
  ),
  AppFeature.askAi => const _TabSpec(Icons.auto_awesome_outlined, 'Питај AI'),
  _ => const _TabSpec(Icons.info_outline, ''),
};
