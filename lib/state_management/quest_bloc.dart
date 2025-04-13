import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';

part 'quest_bloc.freezed.dart';

class QuestBloc extends Bloc<QuestEvent, QuestState> {
  final QuestionsData data;

  QuestBloc(this.data, List<int> questions) : super(QuestState(questions: questions)) {
    on<NextQuestion>(_onNextQuestion);
    on<PrevQuestion>(_onPrevQuestion);
    on<AddAnswer>(_onAddAnswer);
    on<Init>(_onInit);
    on<MoveToQuestion>(_onMoveToQuestiont);
    on<FinalizeTest>(_onFinalizeTest);
  }

  void _onNextQuestion(NextQuestion event, Emitter<QuestState> emit) {
    final nextIndex = state.currentQuestionIndex + 1;
    if (nextIndex >= state.questions.length) return;
    emit(state.copyWith(currentQuestionIndex: nextIndex));
  }

  void _onPrevQuestion(PrevQuestion event, Emitter<QuestState> emit) {
    final nextIndex = state.currentQuestionIndex - 1;
    if (nextIndex < 0) return;
    emit(state.copyWith(currentQuestionIndex: nextIndex));
  }

  void _onAddAnswer(AddAnswer event, Emitter<QuestState> emit) {
    final answers = {...state.answers};
    answers[event.qid] = event.answer;
    _recalculateState(answers, emit);

    final question = data.questions.firstWhere((element) => element.id == event.qid);
    final correctAnswers = question.choices.where((element) => element.isCorrect).toSet();

    repository.addAnswer(event.qid, !setEquals(correctAnswers, event.answer));
  }

  void _recalculateState(Map<int, Set<Choice>> answers, Emitter<QuestState> emit) {
    var score = 0;
    var wrong = 0;
    var right = 0;
    var possibleScore = 0;

    for (var qid in state.questions) {
      final question = data.questions.firstWhere((element) => element.id == qid);
      possibleScore += question.points;
    }

    for (var answer in answers.entries) {
      final question = data.questions.firstWhere((element) => element.id == answer.key);
      final correctAnswers = question.choices.where((element) => element.isCorrect).toSet();

      if (setEquals(correctAnswers, answer.value)) {
        // answer is correct
        right++;
        score += question.points;
      } else {
        wrong++;
      }
    }

    emit(state.copyWith(score: score, wrongAnswers: wrong, rightAnswers: right, possibleScore: possibleScore, answers: answers));
  }

  void _onInit(Init event, Emitter<QuestState> emit) {
    _recalculateState(state.answers, emit);
  }

  void _onMoveToQuestiont(MoveToQuestion event, Emitter<QuestState> emit) {
    final ind = state.questions.indexOf(event.qid);
    emit(state.copyWith(currentQuestionIndex: ind));
  }

  void _onFinalizeTest(FinalizeTest event, Emitter<QuestState> emit) {
    emit(state.copyWith(finalizeTest: true));
  }
}

sealed class QuestEvent {}

class NextQuestion extends QuestEvent {}

class Init extends QuestEvent {}

class PrevQuestion extends QuestEvent {}
class FinalizeTest extends QuestEvent {}

class MoveToQuestion extends QuestEvent {
  int qid;

  MoveToQuestion(this.qid);
}

class AddAnswer extends QuestEvent {
  int qid;
  Set<Choice> answer;

  AddAnswer(this.qid, this.answer);
}

@freezed
sealed class QuestState with _$QuestState {
  const factory QuestState({
    @Default([]) List<int> questions,
    @Default(0) int currentQuestionIndex,
    @Default({}) Map<int, Set<Choice>> answers,
    @Default(0) int wrongAnswers,
    @Default(0) int rightAnswers,
    @Default(0) int score,
    @Default(0) int possibleScore,
    @Default(false) bool finalizeTest,
  }) = _QuestState;
}
