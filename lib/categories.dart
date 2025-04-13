import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      builder: (context, state) {
        if (state.errorMessage != null) {
          return Center(
            child: Text(state.errorMessage!, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.error)),
          );
        }
        final data = state.questionsData;
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
                    SizedBox(height: 17),
                    ListTile(title: Text(category.name, style: Theme.of(context).textTheme.titleMedium!)),
                    for (var subCategory in category.subcategories.where((element) => (state.subCategoriesCount[element.id] ?? 0) > 0))
                      InkWell(
                        onTap: () {

                        },
                        child: ListTile(
                          title: Text(subCategory.description, style: Theme.of(context).textTheme.bodyMedium),
                          subtitle: Text('Вопросов: ${state.subCategoriesCount[subCategory.id]} '),
                        ),
                      ),
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
