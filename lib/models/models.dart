// ignore_for_file: invalid_annotation_target

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';

part 'models.g.dart';

@freezed
sealed class Category with _$Category {
  const factory Category({required String id, required String name, required List<Subcategory> subcategories}) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
}

@freezed
sealed class Subcategory with _$Subcategory {
  const factory Subcategory({@JsonKey(name: 'Id') required int id, @JsonKey(name: 'Description') required String description}) = _Subcategory;

  factory Subcategory.fromJson(Map<String, dynamic> json) => _$SubcategoryFromJson(json);
}

@freezed
sealed class Question with _$Question {
  const factory Question({
    @JsonKey(name: 'qcId') required int id,
    @JsonKey(name: 'qId') required int imageId,
    @JsonKey(name: 'Text') required String text,
    @JsonKey(name: 'ChoicesReq') required int choicesReq,
    @JsonKey(name: 'HasImage') required bool hasImage,
    @JsonKey(name: 'Points') required int points,
    @JsonKey(name: 'Choices') required List<Choice> choices,
    required String categoryId,
    required int subcategoryId,
    String? translation,
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) => _$QuestionFromJson(json);
}

@freezed
sealed class Choice with _$Choice {
  const factory Choice({@JsonKey(name: 'Text') required String text, @JsonKey(name: 'isCorrect') required bool isCorrect, String? translationRu}) = _Choice;

  factory Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);
}

@freezed
sealed class QuestionsData with _$QuestionsData {
  const factory QuestionsData({required List<Category> categories, required List<Question> questions, required List<List<int>> practice}) =
  _QuestionsData;
}

@freezed
abstract class Translation with _$Translation {
  const factory Translation({
    @JsonKey(name: 'qcId') required int id,
    @JsonKey(name: 'qId') required int imageId,
    @JsonKey(name: 'Text') required String text,
    @JsonKey(name: 'Choices') required List<ChoiceTranslation> choices,
  }) = _Translation;

  factory Translation.fromJson(Map<String, dynamic> json) => _$TranslationFromJson(json);
}

@freezed
abstract  class ChoiceTranslation with _$ChoiceTranslation {
  const factory ChoiceTranslation({
    @JsonKey(name: 'Text') required String text,
  }) = _ChoiceTranslation;


  factory ChoiceTranslation.fromJson(Map<String, dynamic> json) =>
      _$ChoiceTranslationFromJson(json);
}