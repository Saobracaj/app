// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
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


/// Adds pattern-matching-related methods to [CategoriesBlocState].
extension CategoriesBlocStatePatterns on CategoriesBlocState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoriesBlocState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoriesBlocState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoriesBlocState value)  $default,){
final _that = this;
switch (_that) {
case _CategoriesBlocState():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoriesBlocState value)?  $default,){
final _that = this;
switch (_that) {
case _CategoriesBlocState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<int, int> subCategoriesCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoriesBlocState() when $default != null:
return $default(_that.subCategoriesCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<int, int> subCategoriesCount)  $default,) {final _that = this;
switch (_that) {
case _CategoriesBlocState():
return $default(_that.subCategoriesCount);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<int, int> subCategoriesCount)?  $default,) {final _that = this;
switch (_that) {
case _CategoriesBlocState() when $default != null:
return $default(_that.subCategoriesCount);case _:
  return null;

}
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
