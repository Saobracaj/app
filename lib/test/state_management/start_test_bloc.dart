import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'start_test_bloc.freezed.dart';

class StartTestBloc extends Bloc<StartTestEvent, StartTestState> {
  StartTestBloc() : super(StartTestState()) {
    on<ToggleRandom>(_setRandom);
    on<ToggleRandomOptionsOrder>(_setRandomOptionsOrder);
    on<ToggleShowWrongAnswers>(_setShowWrongAnswers);
  }

  void _setRandom(ToggleRandom event, Emitter<StartTestState> emit) {
    emit(state.copyWith(random: !state.random));
  }

  void _setRandomOptionsOrder(ToggleRandomOptionsOrder event, Emitter<StartTestState> emit) {
    emit(state.copyWith(randomOptionsOrder: !state.randomOptionsOrder));
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
