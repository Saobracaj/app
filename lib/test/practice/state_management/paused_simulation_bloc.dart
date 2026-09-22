import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/paused_simulation_repository.dart';
import 'paused_simulation_events.dart';
import 'paused_simulation_state.dart';

/// Публикует в дерево виджетов снимок незавершённой симуляции из
/// [PausedSimulationRepository]. Живёт на уровне приложения (`main.dart`):
/// баннер «симуляция на паузе» нужен и на главной, и на странице запуска.
@injectable
class PausedSimulationBloc
    extends Bloc<PausedSimulationEvent, PausedSimulationState> {
  PausedSimulationBloc(this._repository)
    : super(PausedSimulationState(snapshot: _repository.current)) {
    on<PausedSimulationStarted>(_onStarted);
    on<PausedSimulationChanged>(_onChanged);
    on<PausedSimulationDiscarded>(_onDiscarded);
  }

  final PausedSimulationRepository _repository;
  StreamSubscription<void>? _subscription;

  void _onStarted(
    PausedSimulationStarted event,
    Emitter<PausedSimulationState> emit,
  ) {
    emit(state.copyWith(snapshot: _repository.current));
    _subscription ??= _repository.changes.listen(
      (snapshot) => add(PausedSimulationChanged(snapshot)),
    );
  }

  void _onChanged(
    PausedSimulationChanged event,
    Emitter<PausedSimulationState> emit,
  ) => emit(state.copyWith(snapshot: event.snapshot));

  Future<void> _onDiscarded(
    PausedSimulationDiscarded event,
    Emitter<PausedSimulationState> emit,
  ) => _repository.clear();

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
