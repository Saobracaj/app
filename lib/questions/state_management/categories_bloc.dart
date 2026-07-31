import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/models/models.dart';

part 'categories_bloc.freezed.dart';

class CategoriesBloc extends Bloc<CategoriesBlocEvent, CategoriesBlocState> {
  final QuestionsData _data;

  CategoriesBloc(this._data) : super(CategoriesBlocState()) {
    on<Init>(_init);
    add(Init());
  }

  void _init(Init event, Emitter<CategoriesBlocState> emit) {
    final subCategoriesCount = <int, int>{};
    for (var category in _data.categories) {
      for (var subcategory in category.subcategories) {
        subCategoriesCount[subcategory.id] = _getQuestionsCount(subcategory.id, _data.questions);
      }
    }
    emit(state.copyWith(subCategoriesCount: subCategoriesCount));
  }

  int _getQuestionsCount(int subCategoryId, List<Question> questions) {
    return questions.where((element) => element.subcategoryId == subCategoryId).length;
  }
}

sealed class CategoriesBlocEvent {}

class Init extends CategoriesBlocEvent {}

@freezed
sealed class CategoriesBlocState with _$CategoriesBlocState {
  const factory CategoriesBlocState({@Default({}) Map<int, int> subCategoriesCount}) = _CategoriesBlocState;
}
