import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_button.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/questions/state_management/categories_bloc.dart';
import 'package:saobracaj/theme/quiz_colors.dart';
import 'package:saobracaj/test/start_test.dart';

class Categories extends StatefulWidget {
  const Categories({super.key, this.wide = false});

  /// Раскладка широкого экрана из макета веб-версии: подкатегории — плитками
  /// в сетке, а не строками списка.
  final bool wide;

  @override
  State<Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<Categories> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, qState) {
        if (qState.errorMessage != null) {
          return Center(
            child: Text(
              qState.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }
        final data = qState.questionsData;
        if (data == null) {
          return Center(child: CircularProgressIndicator());
        }
        return BlocProvider(
          create: (context) => CategoriesBloc(data),
          child: BlocBuilder<CategoriesBloc, CategoriesBlocState>(
            builder: (context, state) {
              if (widget.wide) {
                final categories = data.categories.where((category) {
                  final ids = category.subcategories.map((e) => e.id);
                  return ids.any(
                    (element) => (state.subCategoriesCount[element] ?? 0) > 0,
                  );
                }).toList();
                return ListView(
                  children: [
                    for (final category in categories)
                      WideContent(
                        padding: const EdgeInsets.fromLTRB(
                          kWidePageHorizontalPadding,
                          0,
                          kWidePageHorizontalPadding,
                          34,
                        ),
                        child: _CategorySection(
                          category: category,
                          counts: state.subCategoriesCount,
                          stats: qState.subStats,
                          questions: data.questions,
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                );
              }
              return ListView(
                children: [
                  for (var category in data.categories.where((category) {
                    var subCategoriesIds = category.subcategories.map(
                      (e) => e.id,
                    );
                    return subCategoriesIds.any(
                      (element) => (state.subCategoriesCount[element] ?? 0) > 0,
                    );
                  })) ...[
                    SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        category.name,
                        style: Theme.of(context).textTheme.titleMedium!,
                      ),
                      trailing: KonspektButton(categoryId: category.id),
                    ),
                    for (final subCategory in category.subcategories.where(
                      (element) =>
                          (state.subCategoriesCount[element.id] ?? 0) > 0,
                    )) ...[
                      InkWell(
                        onTap: () {
                          final interestedQuestions = <Question>[];
                          for (final q in data.questions) {
                            if (q.subcategoryId == subCategory.id) {
                              interestedQuestions.add(q);
                            }
                          }
                          // var interestedQuestions = data.questions.where((element) => element.subcategoryId == subCategory.id);
                          debugPrint(interestedQuestions.toString());
                          final ids = interestedQuestions
                              .map((e) => e.id)
                              .toList();
                          openStartTest(
                            context,
                            ids,
                            subcategory: '${subCategory.id}',
                          );
                        },
                        child: ListTile(
                          title: Text(
                            subCategory.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Вопросов: ${state.subCategoriesCount[subCategory.id]} ',
                          ),
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(48),
                              child: switch (data.questions
                                  .where(
                                    (q) =>
                                        q.subcategoryId == subCategory.id &&
                                        q.hasImage,
                                  )
                                  .firstOrNull) {
                                final cover? => Image.asset(
                                  'assets/img/${cover.imageId}.jpeg',
                                  fit: BoxFit.cover,
                                  width: 48,
                                  height: 48,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.car_crash,
                                      size: 48,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary.withAlpha(50),
                                    );
                                  },
                                ),
                                null => Icon(
                                  Icons.car_crash,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary.withAlpha(50),
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                      if (qState.subStats[subCategory.id.toString()] != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 16.0,
                            left: 45 + 36,
                            bottom: 16,
                          ),
                          child: MiniChart(
                            stats: qState.subStats[subCategory.id.toString()]!,
                          ),
                        ),
                    ],
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Одна категория в раскладке широкого экрана: заголовок со счётчиком и
/// ссылкой на конспект, под ним — сетка плиток подкатегорий.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.counts,
    required this.stats,
    required this.questions,
  });

  final Category category;
  final Map<int, int> counts;
  final Map<String, SubStats> stats;
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subcategories = category.subcategories
        .where((element) => (counts[element.id] ?? 0) > 0)
        .toList();
    final total = subcategories.fold<int>(
      0,
      (sum, element) => sum + (counts[element.id] ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  category.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                LocaleKeys.quest_questions.tr(args: ['$total']),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              KonspektButton(categoryId: category.id),
            ],
          ),
        ),
        ResponsiveGrid(
          minItemWidth: 400,
          children: [
            for (final subCategory in subcategories)
              _SubcategoryCard(
                subCategory: subCategory,
                count: counts[subCategory.id] ?? 0,
                stats: stats[subCategory.id.toString()],
                questions: questions,
              ),
          ],
        ),
      ],
    );
  }
}

/// Плитка подкатегории: обложка, название, число вопросов и мини-гистограмма
/// прогресса справа.
class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({
    required this.subCategory,
    required this.count,
    required this.stats,
    required this.questions,
  });

  final Subcategory subCategory;
  final int count;
  final SubStats? stats;
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = questions
        .where((q) => q.subcategoryId == subCategory.id && q.hasImage)
        .firstOrNull;
    return SurfaceCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      onTap: () {
        final ids = questions
            .where((q) => q.subcategoryId == subCategory.id)
            .map((e) => e.id)
            .toList();
        openStartTest(context, ids, subcategory: '${subCategory.id}');
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: switch (cover) {
                final image? => Image.asset(
                  'assets/img/${image.imageId}.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _CoverPlaceholder(),
                ),
                null => _CoverPlaceholder(),
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subCategory.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      LocaleKeys.quest_questions.tr(args: ['$count']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (stats != null)
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomRight,
                            child: MiniChart(stats: stats!),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Icon(Icons.car_crash, color: scheme.onSurfaceVariant, size: 26),
    );
  }
}

class MiniChart extends StatelessWidget {
  const MiniChart({super.key, required this.stats});

  final SubStats stats;

  @override
  Widget build(BuildContext context) {
    const minHeight = 5.0;
    const maxHeight = 40.0;
    const space = 2.0;
    const w = 16.0;

    final answers = stats.answers;
    // Guard against division by zero (NaN constraints): a session finished with
    // zero answered questions yields a max/allAnswers of 0.
    final rawMax = answers.isNotEmpty
        ? answers.reduce((a, b) => a > b ? a : b)
        : 1;
    final maxValue = rawMax > 0 ? rawMax : 1;
    final allAnswers = stats.allAnswers > 0 ? stats.allAnswers : 1;

    final quiz = Theme.of(context).quiz;

    /// Bar fill and its label colour for one bucket, from "fully mastered" down
    /// to "mostly wrong".
    (Color, Color) barColors(int value) {
      if (value >= stats.allAnswers) return (quiz.correct, quiz.onCorrect);
      final ratio = value / allAnswers;
      if (ratio > 0.9) return (quiz.warning, quiz.onWarning);
      if (ratio < 0.5) return (quiz.wrong, quiz.onWrong);
      return (quiz.info, quiz.onInfo);
    }

    return Row(
      // mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var value in answers) ...[
          Builder(
            builder: (context) {
              final (background, foreground) = barColors(value);
              return Container(
                width: w,
                height:
                    minHeight + (value / maxValue) * (maxHeight - minHeight),
                color: background,
                child: Center(
                  child: FittedBox(
                    child: Text(
                      value.toString(),
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall!.copyWith(color: foreground),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(width: space),
        ],
      ],
    );
  }
}
