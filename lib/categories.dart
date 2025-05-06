import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';
import 'package:saobracaj/state_management/categories_bloc.dart';

class Categories extends StatefulWidget {
  const Categories({super.key});

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
            child: Text(qState.errorMessage!, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.error)),
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
              return ListView(
                children: [
                  for (var category in data.categories.where((category) {
                    var subCategoriesIds = category.subcategories.map((e) => e.id);
                    return subCategoriesIds.any((element) => (state.subCategoriesCount[element] ?? 0) > 0);
                  })) ...[
                    SizedBox(height: 16),
                    ListTile(title: Text(category.name, style: Theme.of(context).textTheme.titleMedium!)),
                    for (final subCategory in category.subcategories.where((element) => (state.subCategoriesCount[element.id] ?? 0) > 0)) ...[
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
                          final ids = interestedQuestions.map((e) => e.id).toList();
                          Routemaster.of(context).push('/start?q=${ids.join(',')}&subcategory=${subCategory.id}');
                        },
                        child: ListTile(
                          title: Text(
                            subCategory.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Вопросов: ${state.subCategoriesCount[subCategory.id]} '),
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(48),
                              child: Image.asset(
                                'assets/img/${data.questions.where((q) => q.subcategoryId == subCategory.id && q.hasImage).firstOrNull?.id}.jpeg',
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.car_crash, size: 48, color: Theme.of(context).colorScheme.secondary.withAlpha(50));
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (qState.subStats[subCategory.id.toString()] != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0, left: 45+36, bottom: 16),
                          child: _MiniChart(stats: qState.subStats[subCategory.id.toString()]!),
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

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.stats});

  final SubStats stats;

  @override
  Widget build(BuildContext context) {
    const minHeight = 5.0;
    const maxHeight = 40.0;
    const space = 2.0;
    const w = 16.0;

    final answers = stats.answers;
    final maxValue = answers.isNotEmpty ? answers.reduce((a, b) => a > b ? a : b) : 1;

    return Row(
      // mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var value in answers) ...[
          Container(
            width: w,
            height: minHeight + (value / maxValue) * (maxHeight - minHeight),
            color:
                value >= stats.allAnswers
                    ? Colors.green
                    : (value / stats.allAnswers > 0.9 ? Color(0xff8a8200) : (value / stats.allAnswers < 0.5 ? Colors.red : Colors.blue)),
            child: Center(
              child: FittedBox(
                child: Text(value.toString(), maxLines: 1, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.white)),
              ),
            ),
          ),
          SizedBox(width: space),
        ],
      ],
    );
  }
}
