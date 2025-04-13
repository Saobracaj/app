// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'all_questions_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AllQuestionsBlocState implements DiagnosticableTreeMixin {

 String? get errorMessage; QuestionsData? get questionsData;
/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllQuestionsBlocStateCopyWith<AllQuestionsBlocState> get copyWith => _$AllQuestionsBlocStateCopyWithImpl<AllQuestionsBlocState>(this as AllQuestionsBlocState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AllQuestionsBlocState'))
    ..add(DiagnosticsProperty('errorMessage', errorMessage))..add(DiagnosticsProperty('questionsData', questionsData));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllQuestionsBlocState&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.questionsData, questionsData) || other.questionsData == questionsData));
}


@override
int get hashCode => Object.hash(runtimeType,errorMessage,questionsData);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AllQuestionsBlocState(errorMessage: $errorMessage, questionsData: $questionsData)';
}


}

/// @nodoc
abstract mixin class $AllQuestionsBlocStateCopyWith<$Res>  {
  factory $AllQuestionsBlocStateCopyWith(AllQuestionsBlocState value, $Res Function(AllQuestionsBlocState) _then) = _$AllQuestionsBlocStateCopyWithImpl;
@useResult
$Res call({
 String? errorMessage, QuestionsData? questionsData
});


$QuestionsDataCopyWith<$Res>? get questionsData;

}
/// @nodoc
class _$AllQuestionsBlocStateCopyWithImpl<$Res>
    implements $AllQuestionsBlocStateCopyWith<$Res> {
  _$AllQuestionsBlocStateCopyWithImpl(this._self, this._then);

  final AllQuestionsBlocState _self;
  final $Res Function(AllQuestionsBlocState) _then;

/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? errorMessage = freezed,Object? questionsData = freezed,}) {
  return _then(_self.copyWith(
errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,questionsData: freezed == questionsData ? _self.questionsData : questionsData // ignore: cast_nullable_to_non_nullable
as QuestionsData?,
  ));
}
/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuestionsDataCopyWith<$Res>? get questionsData {
    if (_self.questionsData == null) {
    return null;
  }

  return $QuestionsDataCopyWith<$Res>(_self.questionsData!, (value) {
    return _then(_self.copyWith(questionsData: value));
  });
}
}


/// @nodoc


class _AllQuestionsBlocState with DiagnosticableTreeMixin implements AllQuestionsBlocState {
  const _AllQuestionsBlocState({this.errorMessage, this.questionsData});
  

@override final  String? errorMessage;
@override final  QuestionsData? questionsData;

/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AllQuestionsBlocStateCopyWith<_AllQuestionsBlocState> get copyWith => __$AllQuestionsBlocStateCopyWithImpl<_AllQuestionsBlocState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AllQuestionsBlocState'))
    ..add(DiagnosticsProperty('errorMessage', errorMessage))..add(DiagnosticsProperty('questionsData', questionsData));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AllQuestionsBlocState&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.questionsData, questionsData) || other.questionsData == questionsData));
}


@override
int get hashCode => Object.hash(runtimeType,errorMessage,questionsData);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AllQuestionsBlocState(errorMessage: $errorMessage, questionsData: $questionsData)';
}


}

/// @nodoc
abstract mixin class _$AllQuestionsBlocStateCopyWith<$Res> implements $AllQuestionsBlocStateCopyWith<$Res> {
  factory _$AllQuestionsBlocStateCopyWith(_AllQuestionsBlocState value, $Res Function(_AllQuestionsBlocState) _then) = __$AllQuestionsBlocStateCopyWithImpl;
@override @useResult
$Res call({
 String? errorMessage, QuestionsData? questionsData
});


@override $QuestionsDataCopyWith<$Res>? get questionsData;

}
/// @nodoc
class __$AllQuestionsBlocStateCopyWithImpl<$Res>
    implements _$AllQuestionsBlocStateCopyWith<$Res> {
  __$AllQuestionsBlocStateCopyWithImpl(this._self, this._then);

  final _AllQuestionsBlocState _self;
  final $Res Function(_AllQuestionsBlocState) _then;

/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? errorMessage = freezed,Object? questionsData = freezed,}) {
  return _then(_AllQuestionsBlocState(
errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,questionsData: freezed == questionsData ? _self.questionsData : questionsData // ignore: cast_nullable_to_non_nullable
as QuestionsData?,
  ));
}

/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuestionsDataCopyWith<$Res>? get questionsData {
    if (_self.questionsData == null) {
    return null;
  }

  return $QuestionsDataCopyWith<$Res>(_self.questionsData!, (value) {
    return _then(_self.copyWith(questionsData: value));
  });
}
}

// dart format on
