import '../domain/paused_simulation.dart';

sealed class PausedSimulationEvent {}

/// Подписаться на репозиторий и взять текущий снимок.
class PausedSimulationStarted extends PausedSimulationEvent {}

/// Пользователь бросил незавершённую симуляцию (или начал новую поверх неё).
class PausedSimulationDiscarded extends PausedSimulationEvent {}

/// Репозиторий сообщил о новом (или стёртом) снимке.
class PausedSimulationChanged extends PausedSimulationEvent {
  PausedSimulationChanged(this.snapshot);

  final PausedSimulation? snapshot;
}
