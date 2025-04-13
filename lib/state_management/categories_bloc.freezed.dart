// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'categories_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CategoriesBlocState implements DiagnosticableTreeMixin {

 Map<int, int> get subCategoriesCount;
/// Create a copy of CategoriesBlocState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoriesBlocStateCopyWith<CategoriesBlocState> get copyWith => _$CategoriesBlocStateCopyWithImpl<CategoriesBlocState>(this as CategoriesBlocState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'CategoriesBlocState'))
    ..add(DiagnosticsProperty('subCategoriesCount', subCategoriesCount));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoriesBlocState&&const DeepCollectionEquality().equals(other.subCategoriesCount, subCategoriesCount));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(subCategoriesCount));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'CategoriesBlocState(subCategoriesCount: $subCategoriesCount)';
}


}

/// @nodoc
abstract mixin class $CategoriesBlocStateCopyWith<$Res>  {
  factory $CategoriesBlocStateCopyWith(CategoriesBlocState value, $Res Function(CategoriesBlocState) _then) = _$CategoriesBlocStateCopyWithImpl;
@useResult
$Res call({
 Map<int, int> subCategoriesCount
});




}
/// @nodoc
class _$CategoriesBlocStateCopyWithImpl<$Res>
    implements $CategoriesBlocStateCopyWith<$Res> {
  _$CategoriesBlocStateCopyWithImpl(this._self, this._then);

  final CategoriesBlocState _self;
  final $Res Function(CategoriesBlocState) _then;

/// Create a copy of CategoriesBlocState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? subCategoriesCount = null,}) {
  return _then(_self.copyWith(
subCategoriesCount: null == subCategoriesCount ? _self.subCategoriesCount : subCategoriesCount // ignore: cast_nullable_to_non_nullable
as Map<int, int>,
  ));
}

}


/// @nodoc


class _CategoriesBlocState with DiagnosticableTreeMixin implements CategoriesBlocState {
  const _CategoriesBlocState({final  Map<int, int> subCategoriesCount = const {}}): _subCategoriesCount = subCategoriesCount;
  

 final  Map<int, int> _subCategoriesCount;
@override@JsonKey() Map<int, int> get subCategoriesCount {
  if (_subCategoriesCount is EqualUnmodifiableMapView) return _subCategoriesCount;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_subCategoriesCount);
}


/// Create a copy of CategoriesBlocState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoriesBlocStateCopyWith<_CategoriesBlocState> get copyWith => __$CategoriesBlocStateCopyWithImpl<_CategoriesBlocState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'CategoriesBlocState'))
    ..add(DiagnosticsProperty('subCategoriesCount', subCategoriesCount));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoriesBlocState&&const DeepCollectionEquality().equals(other._subCategoriesCount, _subCategoriesCount));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_subCategoriesCount));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'CategoriesBlocState(subCategoriesCount: $subCategoriesCount)';
}


}

/// @nodoc
abstract mixin class _$CategoriesBlocStateCopyWith<$Res> implements $CategoriesBlocStateCopyWith<$Res> {
  factory _$CategoriesBlocStateCopyWith(_CategoriesBlocState value, $Res Function(_CategoriesBlocState) _then) = __$CategoriesBlocStateCopyWithImpl;
@override @useResult
$Res call({
 Map<int, int> subCategoriesCount
});




}
/// @nodoc
class __$CategoriesBlocStateCopyWithImpl<$Res>
    implements _$CategoriesBlocStateCopyWith<$Res> {
  __$CategoriesBlocStateCopyWithImpl(this._self, this._then);

  final _CategoriesBlocState _self;
  final $Res Function(_CategoriesBlocState) _then;

/// Create a copy of CategoriesBlocState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? subCategoriesCount = null,}) {
  return _then(_CategoriesBlocState(
subCategoriesCount: null == subCategoriesCount ? _self._subCategoriesCount : subCategoriesCount // ignore: cast_nullable_to_non_nullable
as Map<int, int>,
  ));
}


}

// dart format on
