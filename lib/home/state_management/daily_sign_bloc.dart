import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../zakon/domain/road_sign_index.dart';
import '../domain/home_insights.dart';
import 'daily_sign_events.dart';
import 'daily_sign_state.dart';

/// The «знак дня» flashcard: one road sign from the pravilnik index per day,
/// name hidden until asked. Nothing is persisted — the flip is a moment's
/// self-check, not progress.
@injectable
class DailySignBloc extends Bloc<DailySignEvent, DailySignState> {
  DailySignBloc() : super(const DailySignState()) {
    on<DailySignStarted>(_onStarted);
    on<DailySignRevealed>(
      (event, emit) => emit(state.copyWith(revealed: true)),
    );
  }

  Future<void> _onStarted(
    DailySignStarted event,
    Emitter<DailySignState> emit,
  ) async {
    final List<RoadSignInfo> signs;
    try {
      signs = await RoadSignIndex.all();
    } catch (_) {
      // The pravilnik asset could not be read — no card, nothing else.
      return;
    }
    if (emit.isDone || signs.isEmpty) return;
    emit(state.copyWith(sign: signs[dailyPick(clock.now(), signs.length)]));
  }
}
