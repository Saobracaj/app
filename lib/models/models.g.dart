// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Category _$CategoryFromJson(Map<String, dynamic> json) => _Category(
  id: json['id'] as String,
  name: json['name'] as String,
  subcategories:
      (json['subcategories'] as List<dynamic>)
          .map((e) => Subcategory.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$CategoryToJson(_Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'subcategories': instance.subcategories,
};

_Subcategory _$SubcategoryFromJson(Map<String, dynamic> json) => _Subcategory(
  id: (json['Id'] as num).toInt(),
  description: json['Description'] as String,
);

Map<String, dynamic> _$SubcategoryToJson(_Subcategory instance) =>
    <String, dynamic>{'Id': instance.id, 'Description': instance.description};

_Question _$QuestionFromJson(Map<String, dynamic> json) => _Question(
  id: (json['qcId'] as num).toInt(),
  imageId: (json['qId'] as num).toInt(),
  text: json['Text'] as String,
  choicesReq: (json['ChoicesReq'] as num).toInt(),
  hasImage: json['HasImage'] as bool,
  points: (json['Points'] as num).toInt(),
  choices:
      (json['Choices'] as List<dynamic>)
          .map((e) => Choice.fromJson(e as Map<String, dynamic>))
          .toList(),
  categoryId: json['categoryId'] as String,
  subcategoryId: (json['subcategoryId'] as num).toInt(),
);

Map<String, dynamic> _$QuestionToJson(_Question instance) => <String, dynamic>{
  'qcId': instance.id,
  'qId': instance.imageId,
  'Text': instance.text,
  'ChoicesReq': instance.choicesReq,
  'HasImage': instance.hasImage,
  'Points': instance.points,
  'Choices': instance.choices,
  'categoryId': instance.categoryId,
  'subcategoryId': instance.subcategoryId,
};

_Choice _$ChoiceFromJson(Map<String, dynamic> json) =>
    _Choice(text: json['Text'] as String, isCorrect: json['isCorrect'] as bool);

Map<String, dynamic> _$ChoiceToJson(_Choice instance) => <String, dynamic>{
  'Text': instance.text,
  'isCorrect': instance.isCorrect,
};
