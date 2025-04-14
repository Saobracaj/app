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

 String? get errorMessage; QuestionsData? get questionsData; Map<String, SubStats> get subStats;
/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllQuestionsBlocStateCopyWith<AllQuestionsBlocState> get copyWith => _$AllQuestionsBlocStateCopyWithImpl<AllQuestionsBlocState>(this as AllQuestionsBlocState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AllQuestionsBlocState'))
    ..add(DiagnosticsProperty('errorMessage', errorMessage))..add(DiagnosticsProperty('questionsData', questionsData))..add(DiagnosticsProperty('subStats', subStats));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllQuestionsBlocState&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.questionsData, questionsData) || other.questionsData == questionsData)&&const DeepCollectionEquality().equals(other.subStats, subStats));
}


@override
int get hashCode => Object.hash(runtimeType,errorMessage,questionsData,const DeepCollectionEquality().hash(subStats));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AllQuestionsBlocState(errorMessage: $errorMessage, questionsData: $questionsData, subStats: $subStats)';
}


}

/// @nodoc
abstract mixin class $AllQuestionsBlocStateCopyWith<$Res>  {
  factory $AllQuestionsBlocStateCopyWith(AllQuestionsBlocState value, $Res Function(AllQuestionsBlocState) _then) = _$AllQuestionsBlocStateCopyWithImpl;
@useResult
$Res call({
 String? errorMessage, QuestionsData? questionsData, Map<String, SubStats> subStats
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
@pragma('vm:prefer-inline') @override $Res call({Object? errorMessage = freezed,Object? questionsData = freezed,Object? subStats = null,}) {
  return _then(_self.copyWith(
errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,questionsData: freezed == questionsData ? _self.questionsData : questionsData // ignore: cast_nullable_to_non_nullable
as QuestionsData?,subStats: null == subStats ? _self.subStats : subStats // ignore: cast_nullable_to_non_nullable
as Map<String, SubStats>,
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
  const _AllQuestionsBlocState({this.errorMessage, this.questionsData, final  Map<String, SubStats> subStats = const {}}): _subStats = subStats;
  

@override final  String? errorMessage;
@override final  QuestionsData? questionsData;
 final  Map<String, SubStats> _subStats;
@override@JsonKey() Map<String, SubStats> get subStats {
  if (_subStats is EqualUnmodifiableMapView) return _subStats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_subStats);
}


/// Create a copy of AllQuestionsBlocState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AllQuestionsBlocStateCopyWith<_AllQuestionsBlocState> get copyWith => __$AllQuestionsBlocStateCopyWithImpl<_AllQuestionsBlocState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AllQuestionsBlocState'))
    ..add(DiagnosticsProperty('errorMessage', errorMessage))..add(DiagnosticsProperty('questionsData', questionsData))..add(DiagnosticsProperty('subStats', subStats));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AllQuestionsBlocState&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.questionsData, questionsData) || other.questionsData == questionsData)&&const DeepCollectionEquality().equals(other._subStats, _subStats));
}


@override
int get hashCode => Object.hash(runtimeType,errorMessage,questionsData,const DeepCollectionEquality().hash(_subStats));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AllQuestionsBlocState(errorMessage: $errorMessage, questionsData: $questionsData, subStats: $subStats)';
}


}

/// @nodoc
abstract mixin class _$AllQuestionsBlocStateCopyWith<$Res> implements $AllQuestionsBlocStateCopyWith<$Res> {
  factory _$AllQuestionsBlocStateCopyWith(_AllQuestionsBlocState value, $Res Function(_AllQuestionsBlocState) _then) = __$AllQuestionsBlocStateCopyWithImpl;
@override @useResult
$Res call({
 String? errorMessage, QuestionsData? questionsData, Map<String, SubStats> subStats
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
@override @pragma('vm:prefer-inline') $Res call({Object? errorMessage = freezed,Object? questionsData = freezed,Object? subStats = null,}) {
  return _then(_AllQuestionsBlocState(
errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,questionsData: freezed == questionsData ? _self.questionsData : questionsData // ignore: cast_nullable_to_non_nullable
as QuestionsData?,subStats: null == subStats ? _self._subStats : subStats // ignore: cast_nullable_to_non_nullable
as Map<String, SubStats>,
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
mixin _$SubStats implements DiagnosticableTreeMixin {

 List<int> get answers; int get allAnswers;
/// Create a copy of SubStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubStatsCopyWith<SubStats> get copyWith => _$SubStatsCopyWithImpl<SubStats>(this as SubStats, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'SubStats'))
    ..add(DiagnosticsProperty('answers', answers))..add(DiagnosticsProperty('allAnswers', allAnswers));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubStats&&const DeepCollectionEquality().equals(other.answers, answers)&&(identical(other.allAnswers, allAnswers) || other.allAnswers == allAnswers));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(answers),allAnswers);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'SubStats(answers: $answers, allAnswers: $allAnswers)';
}


}

/// @nodoc
abstract mixin class $SubStatsCopyWith<$Res>  {
  factory $SubStatsCopyWith(SubStats value, $Res Function(SubStats) _then) = _$SubStatsCopyWithImpl;
@useResult
$Res call({
 List<int> answers, int allAnswers
});




}
/// @nodoc
class _$SubStatsCopyWithImpl<$Res>
    implements $SubStatsCopyWith<$Res> {
  _$SubStatsCopyWithImpl(this._self, this._then);

  final SubStats _self;
  final $Res Function(SubStats) _then;

/// Create a copy of SubStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? answers = null,Object? allAnswers = null,}) {
  return _then(_self.copyWith(
answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as List<int>,allAnswers: null == allAnswers ? _self.allAnswers : allAnswers // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// @nodoc


class _SubStats with DiagnosticableTreeMixin implements SubStats {
  const _SubStats({final  List<int> answers = const [], this.allAnswers = 0}): _answers = answers;
  

 final  List<int> _answers;
@override@JsonKey() List<int> get answers {
  if (_answers is EqualUnmodifiableListView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_answers);
}

@override@JsonKey() final  int allAnswers;

/// Create a copy of SubStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubStatsCopyWith<_SubStats> get copyWith => __$SubStatsCopyWithImpl<_SubStats>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'SubStats'))
    ..add(DiagnosticsProperty('answers', answers))..add(DiagnosticsProperty('allAnswers', allAnswers));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubStats&&const DeepCollectionEquality().equals(other._answers, _answers)&&(identical(other.allAnswers, allAnswers) || other.allAnswers == allAnswers));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_answers),allAnswers);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'SubStats(answers: $answers, allAnswers: $allAnswers)';
}


}

/// @nodoc
abstract mixin class _$SubStatsCopyWith<$Res> implements $SubStatsCopyWith<$Res> {
  factory _$SubStatsCopyWith(_SubStats value, $Res Function(_SubStats) _then) = __$SubStatsCopyWithImpl;
@override @useResult
$Res call({
 List<int> answers, int allAnswers
});




}
/// @nodoc
class __$SubStatsCopyWithImpl<$Res>
    implements _$SubStatsCopyWith<$Res> {
  __$SubStatsCopyWithImpl(this._self, this._then);

  final _SubStats _self;
  final $Res Function(_SubStats) _then;

/// Create a copy of SubStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? answers = null,Object? allAnswers = null,}) {
  return _then(_SubStats(
answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as List<int>,allAnswers: null == allAnswers ? _self.allAnswers : allAnswers // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
