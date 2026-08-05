import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import '../data/quiz_preferences_repository.dart';
import '../domain/quiz_option.dart';

part 'start_test_bloc.freezed.dart';

/// Backs the "start a category" screen. The toggles start out at whatever the
/// user picked last time ([QuizPreferencesRepository]) and every change is
/// remembered for the next run.
@injectable
class StartTestBloc extends Bloc<StartTestEvent, StartTestState> {
  StartTestBloc(this._preferences) : super(_initialState(_preferences)) {
    on<ToggleRandom>(_setRandom);
    on<ToggleRandomOptionsOrder>(_setRandomOptionsOrder);
    on<ToggleShowWrongAnswers>(_setShowWrongAnswers);
  }

  final QuizPreferencesRepository _preferences;

  static StartTestState _initialState(QuizPreferencesRepository preferences) =>
      StartTestState(
        random: preferences.isEnabled(QuizOption.shuffleQuestions),
        randomOptionsOrder: preferences.isEnabled(
          QuizOption.shuffleAnswerOptions,
        ),
      );

  void _setRandom(ToggleRandom event, Emitter<StartTestState> emit) {
    final value = !state.random;
    _preferences.setEnabled(QuizOption.shuffleQuestions, value);
    emit(state.copyWith(random: value));
  }

  void _setRandomOptionsOrder(ToggleRandomOptionsOrder event, Emitter<StartTestState> emit) {
    final value = !state.randomOptionsOrder;
    _preferences.setEnabled(QuizOption.shuffleAnswerOptions, value);
    emit(state.copyWith(randomOptionsOrder: value));
  }

  void _setShowWrongAnswers(ToggleShowWrongAnswers event, Emitter<StartTestState> emit) {
    emit(state.copyWith(showWrongAnswers: !state.showWrongAnswers));
  }
}

sealed class StartTestEvent {}

class ToggleRandom extends StartTestEvent {}

class ToggleRandomOptionsOrder extends StartTestEvent {}

class ToggleShowWrongAnswers extends StartTestEvent {}

@freezed
sealed class StartTestState with _$StartTestState {
  const factory StartTestState({@Default(true) bool random, @Default(true) bool randomOptionsOrder, @Default(true) bool showWrongAnswers}) =
      _StartTestState;
}
