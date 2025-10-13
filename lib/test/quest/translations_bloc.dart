import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/data/translations_data_source.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';
import 'package:collection/collection.dart';

part 'translations_bloc.freezed.dart';

class TranslationsBloc extends Bloc<TranslationsEvent, TranslationsState> {


  TranslationsBloc() : super(TranslationsState()) {
    on<ToggleShowTranslation>(_onToggleShowTranslation);
  }


  void _onToggleShowTranslation(ToggleShowTranslation event, Emitter<TranslationsState> emit) {
    emit(state.copyWith(showTranslation: !state.showTranslation));
  }
}

sealed class TranslationsEvent {}

class ToggleShowTranslation extends TranslationsEvent {}

@freezed
abstract class TranslationsState with _$TranslationsState {
  const factory TranslationsState({@Default(false) bool showTranslation}) = _TranslationsState;
}
