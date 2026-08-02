import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/feature_flags_repository.dart';
import '../data/feature_flags_snapshot.dart';
import 'feature_flags_events.dart';
import 'feature_flags_state.dart';

/// App-wide holder that mirrors [FeatureFlagsRepository]'s snapshot into bloc
/// state and forwards local-toggle changes back to it.
///
/// Built directly from the global repository in `main.dart`
/// (`FeatureFlagsBloc(featureFlags)`) — the repository, like
/// `StatisticsSyncService`, is a cross-cutting service constructed in
/// `lib/db/dependencies.dart`, so this bloc carries no injected dependency of
/// its own.
class FeatureFlagsBloc extends Bloc<FeatureFlagsEvent, FeatureFlagsState> {
  FeatureFlagsBloc(this._repository)
    : super(FeatureFlagsState(snapshot: _repository.snapshot)) {
    on<FeatureFlagsStarted>(_onStarted);
    on<FeatureFlagsSnapshotChanged>(_onSnapshotChanged);
    on<FeatureToggled>(_onToggled);
  }

  final FeatureFlagsRepository _repository;
  StreamSubscription<FeatureFlagsSnapshot>? _sub;

  Future<void> _onStarted(
    FeatureFlagsStarted event,
    Emitter<FeatureFlagsState> emit,
  ) async {
    _sub ??= _repository.changes.listen(
      (snapshot) => add(FeatureFlagsSnapshotChanged(snapshot)),
    );
  }

  void _onSnapshotChanged(
    FeatureFlagsSnapshotChanged event,
    Emitter<FeatureFlagsState> emit,
  ) {
    emit(state.copyWith(snapshot: event.snapshot));
  }

  Future<void> _onToggled(
    FeatureToggled event,
    Emitter<FeatureFlagsState> emit,
  ) {
    return _repository.setLocalEnabled(event.feature, event.enabled);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
