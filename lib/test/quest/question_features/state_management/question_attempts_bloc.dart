import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/db/dependencies.dart';

import 'question_attempts_events.dart';
import 'question_attempts_state.dart';

/// Loads the local answer history of a single question for the analysis tab.
/// Built from runtime values only, so it is constructed directly in
/// `BlocProvider(create:)` (same as `QuestionTriesBloc`).
class QuestionAttemptsBloc
    extends Bloc<QuestionAttemptsEvent, QuestionAttemptsState> {
  final int _questionId;

  QuestionAttemptsBloc(this._questionId)
    : super(const QuestionAttemptsState()) {
    on<QuestionAttemptsRequested>(_onRequested);
  }

  void _onRequested(
    QuestionAttemptsRequested event,
    Emitter<QuestionAttemptsState> emit,
  ) async {
    final records = await repository.getAnswersByQuestionId(_questionId);
    emit(state.copyWith(inProgress: false, attempts: records));
  }
}
