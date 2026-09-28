import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/presentation/wide_layout.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';
import '../../test/start_test.dart';
import '../domain/home_insights.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «Покрытие по категориям»: a tile per category with how much of it the
/// user has been through and how well. A tap runs the category's questions
/// the user has not seen yet; a fully covered category leads to the
/// questions screen.
class CategoryCoverageCard extends StatelessWidget {
  const CategoryCoverageCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        if (!state.loaded || state.coverage.isEmpty) {
          return const SizedBox.shrink();
        }
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_coverage_title.tr(),
          icon: Icons.grid_view_outlined,
          child: ResponsiveGrid(
            minItemWidth: 150,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in state.coverage)
                _CoverageTile(category: category, wide: wide),
            ],
          ),
        );
      },
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({required this.category, required this.wide});

  final CategoryCoverageInsight category;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caption = category.answered == 0
        ? LocaleKeys.homeInsights_coverage_untouched.tr()
        : '${LocaleKeys.homeInsights_coverage_progress.tr(args: ['${category.answered}', '${category.total}'])}'
              ' · '
              '${LocaleKeys.homeInsights_coverage_accuracy.tr(args: ['${(category.accuracy * 100).round()}'])}';
    return Material(
      color: wide ? scheme.surfaceContainerLow : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (category.unansweredIds.isEmpty) {
            analytics.logHomeCardOpened(
              card: AppFeature.homeCategoryCoverage.key,
              target: 'questions',
            );
            Routemaster.of(context).push('/questions');
            return;
          }
          analytics.logHomeCardOpened(
            card: AppFeature.homeCategoryCoverage.key,
            target: 'practice',
          );
          openStartTest(context, category.unansweredIds);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(height: 1.25),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: category.coverage,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              HomeCaption(caption, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}
