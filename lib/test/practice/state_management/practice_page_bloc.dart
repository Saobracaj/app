import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/db.dart' show PracticeRecord;
import 'package:saobracaj/db/dependencies.dart' show repository;

part 'practice_page_bloc.freezed.dart';

/// Backs the practice-setup screen: the exam-simulation options the user picks
/// ([PracticeParams], also passed on to the running practice session) plus the
/// list of previous attempts loaded from the local DB.
class PracticePageBloc extends Bloc<PracticePageEvent, PracticeParams> {
  PracticePageBloc() : super(PracticeParams()) {
    on<ToggleRightAnswers>(_onToggleRightAnswers);
    on<ToggleShowStats>(_onToggleShowStats);
    on<ToggleButtonsLikeInExam>(_onToggleButtonsLikeInExam);
    on<LoadPrevTries>(_onLoadPrevTries);
    add(LoadPrevTries());
  }

  void _onToggleRightAnswers(
    ToggleRightAnswers event,
    Emitter<PracticeParams> emit,
  ) {
    emit(state.copyWith(showRightAnswers: !state.showRightAnswers));
  }

  void _onToggleShowStats(ToggleShowStats event, Emitter<PracticeParams> emit) {
    emit(state.copyWith(showStats: !state.showStats));
  }

  void _onToggleButtonsLikeInExam(
    ToggleButtonsLikeInExam event,
    Emitter<PracticeParams> emit,
  ) {
    emit(state.copyWith(buttonsLikeInExam: !state.buttonsLikeInExam));
  }

  void _onLoadPrevTries(
    LoadPrevTries event,
    Emitter<PracticeParams> emit,
  ) async {
    final List<PracticeRecord> records = await repository.getPracticeRecords();
    emit(
      state.copyWith(
        records: records
            .map(
              (e) => PracticeResult(
                points: e.points,
                time: e.time,
                mistakes: e.mistakes,
                durationSeconds: e.durationSeconds,
                wrongAnswers: e.wrongAnswers ?? [],
              ),
            )
            .toList(),
      ),
    );
  }
}

sealed class PracticePageEvent {}

class ToggleRightAnswers extends PracticePageEvent {}

class ToggleShowStats extends PracticePageEvent {}

class ToggleButtonsLikeInExam extends PracticePageEvent {}

class LoadPrevTries extends PracticePageEvent {}

/// Exam-simulation configuration. Doubles as [PracticePageBloc]'s state and as
/// the config passed to the running practice session.
@freezed
sealed class PracticeParams with _$PracticeParams {
  const factory PracticeParams({
    @Default(false) bool showRightAnswers,
    @Default(false) bool showStats,
    @Default(false) bool buttonsLikeInExam,
    @Default([]) List<PracticeResult> records,
  }) = _PracticeParams;
}

@freezed
sealed class PracticeResult with _$PracticeResult {
  const factory PracticeResult({
    required int points,
    required DateTime time,
    required int mistakes,
    required int durationSeconds,
    @Default([]) List<int> wrongAnswers,
  }) = _PracticeResult;
}
