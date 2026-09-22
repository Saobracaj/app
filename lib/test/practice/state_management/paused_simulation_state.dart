import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/paused_simulation.dart';

part 'paused_simulation_state.freezed.dart';

/// Есть ли на устройстве незавершённая симуляция — то, по чему главная и
/// страница запуска решают, показывать ли баннер «симуляция на паузе».
@freezed
sealed class PausedSimulationState with _$PausedSimulationState {
  const factory PausedSimulationState({PausedSimulation? snapshot}) =
      _PausedSimulationState;
}
