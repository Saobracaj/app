import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:saobracaj/db/db.dart' show PracticeRecord;
import 'package:saobracaj/db/dependencies.dart' show repository;
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/domain/quiz_option.dart';

part 'practice_page_bloc.freezed.dart';

/// Backs the practice-setup screen: the exam-simulation options the user picks
/// ([PracticeParams], also passed on to the running practice session) plus the
/// list of previous attempts loaded from the local DB.
///
/// The options start out at the user's last choice
/// ([QuizPreferencesRepository]) and each toggle is remembered for the next
/// simulation.
@injectable
class PracticePageBloc extends Bloc<PracticePageEvent, PracticeParams> {
  PracticePageBloc(this._preferences) : super(_initialParams(_preferences)) {
    on<ToggleRightAnswers>(_onToggleRightAnswers);
    on<ToggleShowStats>(_onToggleShowStats);
    on<ToggleButtonsLikeInExam>(_onToggleButtonsLikeInExam);
    on<LoadPrevTries>(_onLoadPrevTries);
    add(LoadPrevTries());
  }

  final QuizPreferencesRepository _preferences;

  static PracticeParams _initialParams(
    QuizPreferencesRepository preferences,
  ) => PracticeParams(
    showRightAnswers: preferences.isEnabled(
      QuizOption.practiceShowRightAnswers,
    ),
    showStats: preferences.isEnabled(QuizOption.practiceShowStats),
    buttonsLikeInExam: preferences.isEnabled(
      QuizOption.practiceButtonsLikeInExam,
    ),
  );

  void _onToggleRightAnswers(
    ToggleRightAnswers event,
    Emitter<PracticeParams> emit,
  ) {
    final value = !state.showRightAnswers;
    _preferences.setEnabled(QuizOption.practiceShowRightAnswers, value);
    emit(state.copyWith(showRightAnswers: value));
  }

  void _onToggleShowStats(ToggleShowStats event, Emitter<PracticeParams> emit) {
    final value = !state.showStats;
    _preferences.setEnabled(QuizOption.practiceShowStats, value);
    emit(state.copyWith(showStats: value));
  }

  void _onToggleButtonsLikeInExam(
    ToggleButtonsLikeInExam event,
    Emitter<PracticeParams> emit,
  ) {
    final value = !state.buttonsLikeInExam;
    _preferences.setEnabled(QuizOption.practiceButtonsLikeInExam, value);
    emit(state.copyWith(buttonsLikeInExam: value));
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
