
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';

part 'translations_bloc.freezed.dart';

class TranslationsBloc extends Bloc<TranslationsEvent, TranslationsState> {


  TranslationsBloc() : super(TranslationsState()) {
    on<ToggleShowTranslation>(_onToggleShowTranslation);
    on<ResetTranslation>(_onResetTranslation);
  }


  void _onToggleShowTranslation(ToggleShowTranslation event, Emitter<TranslationsState> emit) {
    final enabled = !state.showTranslation;
    analytics.logTranslationToggled(enabled: enabled);
    emit(state.copyWith(showTranslation: enabled));
  }

  // Смена вопроса намеренно сбрасывает переключатель «РУ».
  void _onResetTranslation(ResetTranslation event, Emitter<TranslationsState> emit) {
    emit(state.copyWith(showTranslation: false));
  }
}

sealed class TranslationsEvent {}

class ToggleShowTranslation extends TranslationsEvent {}

class ResetTranslation extends TranslationsEvent {}

@freezed
abstract class TranslationsState with _$TranslationsState {
  const factory TranslationsState({@Default(false) bool showTranslation}) = _TranslationsState;
}
