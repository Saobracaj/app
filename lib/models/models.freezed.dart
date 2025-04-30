// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Category implements DiagnosticableTreeMixin {

 String get id; String get name; List<Subcategory> get subcategories;
/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryCopyWith<Category> get copyWith => _$CategoryCopyWithImpl<Category>(this as Category, _$identity);

  /// Serializes this Category to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Category'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('subcategories', subcategories));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Category&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.subcategories, subcategories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(subcategories));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Category(id: $id, name: $name, subcategories: $subcategories)';
}


}

/// @nodoc
abstract mixin class $CategoryCopyWith<$Res>  {
  factory $CategoryCopyWith(Category value, $Res Function(Category) _then) = _$CategoryCopyWithImpl;
@useResult
$Res call({
 String id, String name, List<Subcategory> subcategories
});




}
/// @nodoc
class _$CategoryCopyWithImpl<$Res>
    implements $CategoryCopyWith<$Res> {
  _$CategoryCopyWithImpl(this._self, this._then);

  final Category _self;
  final $Res Function(Category) _then;

/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? subcategories = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,subcategories: null == subcategories ? _self.subcategories : subcategories // ignore: cast_nullable_to_non_nullable
as List<Subcategory>,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Category with DiagnosticableTreeMixin implements Category {
  const _Category({required this.id, required this.name, required final  List<Subcategory> subcategories}): _subcategories = subcategories;
  factory _Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);

@override final  String id;
@override final  String name;
 final  List<Subcategory> _subcategories;
@override List<Subcategory> get subcategories {
  if (_subcategories is EqualUnmodifiableListView) return _subcategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subcategories);
}


/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryCopyWith<_Category> get copyWith => __$CategoryCopyWithImpl<_Category>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CategoryToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Category'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('subcategories', subcategories));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Category&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._subcategories, _subcategories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_subcategories));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Category(id: $id, name: $name, subcategories: $subcategories)';
}


}

/// @nodoc
abstract mixin class _$CategoryCopyWith<$Res> implements $CategoryCopyWith<$Res> {
  factory _$CategoryCopyWith(_Category value, $Res Function(_Category) _then) = __$CategoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, List<Subcategory> subcategories
});




}
/// @nodoc
class __$CategoryCopyWithImpl<$Res>
    implements _$CategoryCopyWith<$Res> {
  __$CategoryCopyWithImpl(this._self, this._then);

  final _Category _self;
  final $Res Function(_Category) _then;

/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? subcategories = null,}) {
  return _then(_Category(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,subcategories: null == subcategories ? _self._subcategories : subcategories // ignore: cast_nullable_to_non_nullable
as List<Subcategory>,
  ));
}


}


/// @nodoc
mixin _$Subcategory implements DiagnosticableTreeMixin {

@JsonKey(name: 'Id') int get id;@JsonKey(name: 'Description') String get description;
/// Create a copy of Subcategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubcategoryCopyWith<Subcategory> get copyWith => _$SubcategoryCopyWithImpl<Subcategory>(this as Subcategory, _$identity);

  /// Serializes this Subcategory to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Subcategory'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('description', description));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subcategory&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Subcategory(id: $id, description: $description)';
}


}

/// @nodoc
abstract mixin class $SubcategoryCopyWith<$Res>  {
  factory $SubcategoryCopyWith(Subcategory value, $Res Function(Subcategory) _then) = _$SubcategoryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'Id') int id,@JsonKey(name: 'Description') String description
});




}
/// @nodoc
class _$SubcategoryCopyWithImpl<$Res>
    implements $SubcategoryCopyWith<$Res> {
  _$SubcategoryCopyWithImpl(this._self, this._then);

  final Subcategory _self;
  final $Res Function(Subcategory) _then;

/// Create a copy of Subcategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? description = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Subcategory with DiagnosticableTreeMixin implements Subcategory {
  const _Subcategory({@JsonKey(name: 'Id') required this.id, @JsonKey(name: 'Description') required this.description});
  factory _Subcategory.fromJson(Map<String, dynamic> json) => _$SubcategoryFromJson(json);

@override@JsonKey(name: 'Id') final  int id;
@override@JsonKey(name: 'Description') final  String description;

/// Create a copy of Subcategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubcategoryCopyWith<_Subcategory> get copyWith => __$SubcategoryCopyWithImpl<_Subcategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubcategoryToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Subcategory'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('description', description));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subcategory&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Subcategory(id: $id, description: $description)';
}


}

/// @nodoc
abstract mixin class _$SubcategoryCopyWith<$Res> implements $SubcategoryCopyWith<$Res> {
  factory _$SubcategoryCopyWith(_Subcategory value, $Res Function(_Subcategory) _then) = __$SubcategoryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'Id') int id,@JsonKey(name: 'Description') String description
});




}
/// @nodoc
class __$SubcategoryCopyWithImpl<$Res>
    implements _$SubcategoryCopyWith<$Res> {
  __$SubcategoryCopyWithImpl(this._self, this._then);

  final _Subcategory _self;
  final $Res Function(_Subcategory) _then;

/// Create a copy of Subcategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? description = null,}) {
  return _then(_Subcategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Question implements DiagnosticableTreeMixin {

@JsonKey(name: 'qcId') int get id;@JsonKey(name: 'qId') int get imageId;@JsonKey(name: 'Text') String get text;@JsonKey(name: 'ChoicesReq') int get choicesReq;@JsonKey(name: 'HasImage') bool get hasImage;@JsonKey(name: 'Points') int get points;@JsonKey(name: 'Choices') List<Choice> get choices; String get categoryId; int get subcategoryId;
/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionCopyWith<Question> get copyWith => _$QuestionCopyWithImpl<Question>(this as Question, _$identity);

  /// Serializes this Question to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Question'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('imageId', imageId))..add(DiagnosticsProperty('text', text))..add(DiagnosticsProperty('choicesReq', choicesReq))..add(DiagnosticsProperty('hasImage', hasImage))..add(DiagnosticsProperty('points', points))..add(DiagnosticsProperty('choices', choices))..add(DiagnosticsProperty('categoryId', categoryId))..add(DiagnosticsProperty('subcategoryId', subcategoryId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Question&&(identical(other.id, id) || other.id == id)&&(identical(other.imageId, imageId) || other.imageId == imageId)&&(identical(other.text, text) || other.text == text)&&(identical(other.choicesReq, choicesReq) || other.choicesReq == choicesReq)&&(identical(other.hasImage, hasImage) || other.hasImage == hasImage)&&(identical(other.points, points) || other.points == points)&&const DeepCollectionEquality().equals(other.choices, choices)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.subcategoryId, subcategoryId) || other.subcategoryId == subcategoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,imageId,text,choicesReq,hasImage,points,const DeepCollectionEquality().hash(choices),categoryId,subcategoryId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Question(id: $id, imageId: $imageId, text: $text, choicesReq: $choicesReq, hasImage: $hasImage, points: $points, choices: $choices, categoryId: $categoryId, subcategoryId: $subcategoryId)';
}


}

/// @nodoc
abstract mixin class $QuestionCopyWith<$Res>  {
  factory $QuestionCopyWith(Question value, $Res Function(Question) _then) = _$QuestionCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'qcId') int id,@JsonKey(name: 'qId') int imageId,@JsonKey(name: 'Text') String text,@JsonKey(name: 'ChoicesReq') int choicesReq,@JsonKey(name: 'HasImage') bool hasImage,@JsonKey(name: 'Points') int points,@JsonKey(name: 'Choices') List<Choice> choices, String categoryId, int subcategoryId
});




}
/// @nodoc
class _$QuestionCopyWithImpl<$Res>
    implements $QuestionCopyWith<$Res> {
  _$QuestionCopyWithImpl(this._self, this._then);

  final Question _self;
  final $Res Function(Question) _then;

/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? imageId = null,Object? text = null,Object? choicesReq = null,Object? hasImage = null,Object? points = null,Object? choices = null,Object? categoryId = null,Object? subcategoryId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,imageId: null == imageId ? _self.imageId : imageId // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,choicesReq: null == choicesReq ? _self.choicesReq : choicesReq // ignore: cast_nullable_to_non_nullable
as int,hasImage: null == hasImage ? _self.hasImage : hasImage // ignore: cast_nullable_to_non_nullable
as bool,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,choices: null == choices ? _self.choices : choices // ignore: cast_nullable_to_non_nullable
as List<Choice>,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,subcategoryId: null == subcategoryId ? _self.subcategoryId : subcategoryId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Question with DiagnosticableTreeMixin implements Question {
  const _Question({@JsonKey(name: 'qcId') required this.id, @JsonKey(name: 'qId') required this.imageId, @JsonKey(name: 'Text') required this.text, @JsonKey(name: 'ChoicesReq') required this.choicesReq, @JsonKey(name: 'HasImage') required this.hasImage, @JsonKey(name: 'Points') required this.points, @JsonKey(name: 'Choices') required final  List<Choice> choices, required this.categoryId, required this.subcategoryId}): _choices = choices;
  factory _Question.fromJson(Map<String, dynamic> json) => _$QuestionFromJson(json);

@override@JsonKey(name: 'qcId') final  int id;
@override@JsonKey(name: 'qId') final  int imageId;
@override@JsonKey(name: 'Text') final  String text;
@override@JsonKey(name: 'ChoicesReq') final  int choicesReq;
@override@JsonKey(name: 'HasImage') final  bool hasImage;
@override@JsonKey(name: 'Points') final  int points;
 final  List<Choice> _choices;
@override@JsonKey(name: 'Choices') List<Choice> get choices {
  if (_choices is EqualUnmodifiableListView) return _choices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_choices);
}

@override final  String categoryId;
@override final  int subcategoryId;

/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuestionCopyWith<_Question> get copyWith => __$QuestionCopyWithImpl<_Question>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuestionToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Question'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('imageId', imageId))..add(DiagnosticsProperty('text', text))..add(DiagnosticsProperty('choicesReq', choicesReq))..add(DiagnosticsProperty('hasImage', hasImage))..add(DiagnosticsProperty('points', points))..add(DiagnosticsProperty('choices', choices))..add(DiagnosticsProperty('categoryId', categoryId))..add(DiagnosticsProperty('subcategoryId', subcategoryId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Question&&(identical(other.id, id) || other.id == id)&&(identical(other.imageId, imageId) || other.imageId == imageId)&&(identical(other.text, text) || other.text == text)&&(identical(other.choicesReq, choicesReq) || other.choicesReq == choicesReq)&&(identical(other.hasImage, hasImage) || other.hasImage == hasImage)&&(identical(other.points, points) || other.points == points)&&const DeepCollectionEquality().equals(other._choices, _choices)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.subcategoryId, subcategoryId) || other.subcategoryId == subcategoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,imageId,text,choicesReq,hasImage,points,const DeepCollectionEquality().hash(_choices),categoryId,subcategoryId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Question(id: $id, imageId: $imageId, text: $text, choicesReq: $choicesReq, hasImage: $hasImage, points: $points, choices: $choices, categoryId: $categoryId, subcategoryId: $subcategoryId)';
}


}

/// @nodoc
abstract mixin class _$QuestionCopyWith<$Res> implements $QuestionCopyWith<$Res> {
  factory _$QuestionCopyWith(_Question value, $Res Function(_Question) _then) = __$QuestionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'qcId') int id,@JsonKey(name: 'qId') int imageId,@JsonKey(name: 'Text') String text,@JsonKey(name: 'ChoicesReq') int choicesReq,@JsonKey(name: 'HasImage') bool hasImage,@JsonKey(name: 'Points') int points,@JsonKey(name: 'Choices') List<Choice> choices, String categoryId, int subcategoryId
});




}
/// @nodoc
class __$QuestionCopyWithImpl<$Res>
    implements _$QuestionCopyWith<$Res> {
  __$QuestionCopyWithImpl(this._self, this._then);

  final _Question _self;
  final $Res Function(_Question) _then;

/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? imageId = null,Object? text = null,Object? choicesReq = null,Object? hasImage = null,Object? points = null,Object? choices = null,Object? categoryId = null,Object? subcategoryId = null,}) {
  return _then(_Question(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,imageId: null == imageId ? _self.imageId : imageId // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,choicesReq: null == choicesReq ? _self.choicesReq : choicesReq // ignore: cast_nullable_to_non_nullable
as int,hasImage: null == hasImage ? _self.hasImage : hasImage // ignore: cast_nullable_to_non_nullable
as bool,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,choices: null == choices ? _self._choices : choices // ignore: cast_nullable_to_non_nullable
as List<Choice>,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,subcategoryId: null == subcategoryId ? _self.subcategoryId : subcategoryId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Choice implements DiagnosticableTreeMixin {

@JsonKey(name: 'Text') String get text;@JsonKey(name: 'isCorrect') bool get isCorrect;
/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChoiceCopyWith<Choice> get copyWith => _$ChoiceCopyWithImpl<Choice>(this as Choice, _$identity);

  /// Serializes this Choice to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Choice'))
    ..add(DiagnosticsProperty('text', text))..add(DiagnosticsProperty('isCorrect', isCorrect));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Choice&&(identical(other.text, text) || other.text == text)&&(identical(other.isCorrect, isCorrect) || other.isCorrect == isCorrect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,isCorrect);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Choice(text: $text, isCorrect: $isCorrect)';
}


}

/// @nodoc
abstract mixin class $ChoiceCopyWith<$Res>  {
  factory $ChoiceCopyWith(Choice value, $Res Function(Choice) _then) = _$ChoiceCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'Text') String text,@JsonKey(name: 'isCorrect') bool isCorrect
});




}
/// @nodoc
class _$ChoiceCopyWithImpl<$Res>
    implements $ChoiceCopyWith<$Res> {
  _$ChoiceCopyWithImpl(this._self, this._then);

  final Choice _self;
  final $Res Function(Choice) _then;

/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? isCorrect = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,isCorrect: null == isCorrect ? _self.isCorrect : isCorrect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Choice with DiagnosticableTreeMixin implements Choice {
  const _Choice({@JsonKey(name: 'Text') required this.text, @JsonKey(name: 'isCorrect') required this.isCorrect});
  factory _Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);

@override@JsonKey(name: 'Text') final  String text;
@override@JsonKey(name: 'isCorrect') final  bool isCorrect;

/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChoiceCopyWith<_Choice> get copyWith => __$ChoiceCopyWithImpl<_Choice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChoiceToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Choice'))
    ..add(DiagnosticsProperty('text', text))..add(DiagnosticsProperty('isCorrect', isCorrect));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Choice&&(identical(other.text, text) || other.text == text)&&(identical(other.isCorrect, isCorrect) || other.isCorrect == isCorrect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,isCorrect);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Choice(text: $text, isCorrect: $isCorrect)';
}


}

/// @nodoc
abstract mixin class _$ChoiceCopyWith<$Res> implements $ChoiceCopyWith<$Res> {
  factory _$ChoiceCopyWith(_Choice value, $Res Function(_Choice) _then) = __$ChoiceCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'Text') String text,@JsonKey(name: 'isCorrect') bool isCorrect
});




}
/// @nodoc
class __$ChoiceCopyWithImpl<$Res>
    implements _$ChoiceCopyWith<$Res> {
  __$ChoiceCopyWithImpl(this._self, this._then);

  final _Choice _self;
  final $Res Function(_Choice) _then;

/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? isCorrect = null,}) {
  return _then(_Choice(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,isCorrect: null == isCorrect ? _self.isCorrect : isCorrect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$QuestionsData implements DiagnosticableTreeMixin {

 List<Category> get categories; List<Question> get questions; List<List<int>> get practice;
/// Create a copy of QuestionsData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionsDataCopyWith<QuestionsData> get copyWith => _$QuestionsDataCopyWithImpl<QuestionsData>(this as QuestionsData, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'QuestionsData'))
    ..add(DiagnosticsProperty('categories', categories))..add(DiagnosticsProperty('questions', questions))..add(DiagnosticsProperty('practice', practice));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionsData&&const DeepCollectionEquality().equals(other.categories, categories)&&const DeepCollectionEquality().equals(other.questions, questions)&&const DeepCollectionEquality().equals(other.practice, practice));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(categories),const DeepCollectionEquality().hash(questions),const DeepCollectionEquality().hash(practice));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'QuestionsData(categories: $categories, questions: $questions, practice: $practice)';
}


}

/// @nodoc
abstract mixin class $QuestionsDataCopyWith<$Res>  {
  factory $QuestionsDataCopyWith(QuestionsData value, $Res Function(QuestionsData) _then) = _$QuestionsDataCopyWithImpl;
@useResult
$Res call({
 List<Category> categories, List<Question> questions, List<List<int>> practice
});




}
/// @nodoc
class _$QuestionsDataCopyWithImpl<$Res>
    implements $QuestionsDataCopyWith<$Res> {
  _$QuestionsDataCopyWithImpl(this._self, this._then);

  final QuestionsData _self;
  final $Res Function(QuestionsData) _then;

/// Create a copy of QuestionsData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? categories = null,Object? questions = null,Object? practice = null,}) {
  return _then(_self.copyWith(
categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<Category>,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<Question>,practice: null == practice ? _self.practice : practice // ignore: cast_nullable_to_non_nullable
as List<List<int>>,
  ));
}

}


/// @nodoc


class _QuestionsData with DiagnosticableTreeMixin implements QuestionsData {
  const _QuestionsData({required final  List<Category> categories, required final  List<Question> questions, required final  List<List<int>> practice}): _categories = categories,_questions = questions,_practice = practice;
  

 final  List<Category> _categories;
@override List<Category> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  List<Question> _questions;
@override List<Question> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}

 final  List<List<int>> _practice;
@override List<List<int>> get practice {
  if (_practice is EqualUnmodifiableListView) return _practice;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_practice);
}


/// Create a copy of QuestionsData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuestionsDataCopyWith<_QuestionsData> get copyWith => __$QuestionsDataCopyWithImpl<_QuestionsData>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'QuestionsData'))
    ..add(DiagnosticsProperty('categories', categories))..add(DiagnosticsProperty('questions', questions))..add(DiagnosticsProperty('practice', practice));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuestionsData&&const DeepCollectionEquality().equals(other._categories, _categories)&&const DeepCollectionEquality().equals(other._questions, _questions)&&const DeepCollectionEquality().equals(other._practice, _practice));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_questions),const DeepCollectionEquality().hash(_practice));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'QuestionsData(categories: $categories, questions: $questions, practice: $practice)';
}


}

/// @nodoc
abstract mixin class _$QuestionsDataCopyWith<$Res> implements $QuestionsDataCopyWith<$Res> {
  factory _$QuestionsDataCopyWith(_QuestionsData value, $Res Function(_QuestionsData) _then) = __$QuestionsDataCopyWithImpl;
@override @useResult
$Res call({
 List<Category> categories, List<Question> questions, List<List<int>> practice
});




}
/// @nodoc
class __$QuestionsDataCopyWithImpl<$Res>
    implements _$QuestionsDataCopyWith<$Res> {
  __$QuestionsDataCopyWithImpl(this._self, this._then);

  final _QuestionsData _self;
  final $Res Function(_QuestionsData) _then;

/// Create a copy of QuestionsData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? categories = null,Object? questions = null,Object? practice = null,}) {
  return _then(_QuestionsData(
categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<Category>,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<Question>,practice: null == practice ? _self._practice : practice // ignore: cast_nullable_to_non_nullable
as List<List<int>>,
  ));
}


}

// dart format on
