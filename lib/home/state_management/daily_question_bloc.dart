import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics_service.dart';
import '../../db/answer_repository.dart';
import '../data/home_preferences_repository.dart';
import '../domain/home_insights.dart';
import 'daily_question_events.dart';
import 'daily_question_state.dart';

/// The «вопрос дня» card: one question, the same for everybody on a given day,
/// answered right on the home screen. A graded answer counts like any other
/// (it goes into the local history, so the readiness and the auto lists see
/// it) and is remembered until midnight, so reopening the app shows the
/// verdict rather than the question again.
@injectable
class DailyQuestionBloc extends Bloc<DailyQuestionEvent, DailyQuestionState> {
  DailyQuestionBloc(this._preferences, this._answers)
    : super(const DailyQuestionState()) {
    on<DailyQuestionStarted>(_onStarted);
    on<DailyQuestionChoiceToggled>(_onToggled);
    on<DailyQuestionChecked>(_onChecked);
  }

  final HomePreferencesRepository _preferences;
  final AnswerRepository _answers;

  static final _dayFormat = DateFormat('yyyy-MM-dd');

  Future<void> _onStarted(
    DailyQuestionStarted event,
    Emitter<DailyQuestionState> emit,
  ) async {
    // The section re-sends the bank on every rebuild of the home screen; the
    // question is picked once.
    if (state.question != null) return;
    final now = clock.now();
    final question = pickDailyQuestion(event.questions, now);
    if (question == null) return;
    final stored = await _preferences.dailyQuestionAnswer();
    if (emit.isDone) return;
    var next = DailyQuestionState(question: question);
    if (stored != null &&
        stored.questionId == question.id &&
        stored.day == _dayFormat.format(now)) {
      final selected = stored.selected.toSet();
      next = next.copyWith(
        selected: selected,
        graded: true,
        correct: _isCorrect(next, selected),
      );
    }
    emit(next);
  }

  void _onToggled(
    DailyQuestionChoiceToggled event,
    Emitter<DailyQuestionState> emit,
  ) {
    if (state.graded || state.question == null) return;
    final selected = {...state.selected};
    if (!selected.remove(event.index)) selected.add(event.index);
    emit(state.copyWith(selected: selected));
  }

  Future<void> _onChecked(
    DailyQuestionChecked event,
    Emitter<DailyQuestionState> emit,
  ) async {
    final question = state.question;
    if (question == null || state.graded || state.selected.isEmpty) return;
    final correct = _isCorrect(state, state.selected);
    emit(state.copyWith(graded: true, correct: correct));
    analytics.logQuestionAnswered(
      questionId: question.id,
      correct: correct,
      mode: 'daily',
    );
    await _preferences.setDailyQuestionAnswer(
      DailyQuestionAnswer(
        day: _dayFormat.format(clock.now()),
        questionId: question.id,
        selected: state.selected.toList()..sort(),
      ),
    );
    await _answers.addAnswer(question.id, !correct);
  }

  static bool _isCorrect(DailyQuestionState state, Set<int> selected) {
    final right = state.correctIndices;
    return selected.length == right.length && selected.containsAll(right);
  }
}
