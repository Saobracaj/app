import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/db.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/practice/practice_page.dart';

part 'practice_bloc.freezed.dart';

const _examDuration = Duration(minutes: 45);

class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  late QuestionsData data;
  final PracticeParams params;
  DateTime? _startTime;

  StreamSubscription? _timeSub;

  PracticeBloc(QuestionsData data, this.params) : super(PracticeState()) {
    final questions = <Question>[];
    for (var q in data.questions) {
      final newQuestion = q.copyWith(choices: [...q.choices]..shuffle());
      questions.add(newQuestion);
    }

    this.data = data.copyWith(questions: questions);

    on<NextQuestion>(_onNextQuestion);
    on<PrevQuestion>(_onPrevQuestion);
    on<AddAnswer>(_onAddAnswer);
    on<Init>(_onInit);
    on<MoveToQuestion>(_onMoveToQuestiont);
    on<FinalizeTest>(_onFinalizeTest);
    on<TimerTick>(_onTimerTick);
    on<ToggleMarkQuestion>(_onToggleMarkQuestion);
    on<NavigateToQuestion>(_onNavigateToQuestion);

    _timeSub = Stream.periodic(Duration(seconds: 1)).listen((event) => add(TimerTick()));
  }

  void _onNextQuestion(NextQuestion event, Emitter<PracticeState> emit) {
    final nextIndex = state.currentQuestionIndex + 1;
    if (nextIndex >= state.questions.length) return;
    _navigateToIndex(nextIndex, emit);
  }

  void _onPrevQuestion(PrevQuestion event, Emitter<PracticeState> emit) {
    final nextIndex = state.currentQuestionIndex - 1;
    if (nextIndex < 0) return;
    _navigateToIndex(nextIndex, emit);
  }

  void _navigateToIndex(int index, Emitter<PracticeState> emit) {
    final curQuestion = data.questions.firstWhere((element) => element.id == state.questions[index]);
    final curAnswers = state.answers[curQuestion.id];
    emit(state.copyWith(currentQuestionIndex: index, currentQuestion: curQuestion, currentAnswers: curAnswers));
  }

  void _onAddAnswer(AddAnswer event, Emitter<PracticeState> emit) {
    final answers = {...state.answers};
    answers[event.qid] = event.answer;
    _recalculateState(answers, emit);

    final question = data.questions.firstWhere((element) => element.id == event.qid);
    final correctAnswers = question.choices.where((element) => element.isCorrect).toSet();

    repository.addAnswer(event.qid, !setEquals(correctAnswers, event.answer));
  }

  void _recalculateState(Map<int, Set<Choice>> answers, Emitter<PracticeState> emit) {
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

  void _onInit(Init event, Emitter<PracticeState> emit) {
    final questions = data.practice[Random().nextInt(data.practice.length)];
    emit(state.copyWith(questions: questions));
    _recalculateState(state.answers, emit);
    _navigateToIndex(0, emit);
    _startTime = DateTime.now();
  }

  void _onMoveToQuestiont(MoveToQuestion event, Emitter<PracticeState> emit) {
    final ind = state.questions.indexOf(event.qid);
    emit(state.copyWith(currentQuestionIndex: ind));
  }

  void _onFinalizeTest(FinalizeTest event, Emitter<PracticeState> emit) async {
    emit(state.copyWith(finalizeTest: true));

    _timeSub?.cancel();
    _timeSub == null;

    var pointsSummary = 0;
    final wrongAnswers = <int>[];
    final qs = data.questions;
    for (var a in state.questions) {
      final q = qs.firstWhere((element) => element.id == a);
      final answers = state.answers[q.id] ?? {};
      if (!setEquals(q.choices.where((element) => element.isCorrect).toSet(), answers)) {
        wrongAnswers.add(q.id);
      } else {
        pointsSummary += q.points;
      }
    }

    repository.insertPracticeRecord(
      PracticeRecordsCompanion(
        points: Value(pointsSummary),
        time: Value(DateTime.now()),
        mistakes: Value(wrongAnswers.length),
        durationSeconds: Value((DateTime.now().difference(_startTime!)).inSeconds),
        wrongAnswers: Value(wrongAnswers),
      ),
    );
  }

  @override
  Future<void> close() {
    _timeSub?.cancel();
    return super.close();
  }

  void _onTimerTick(TimerTick event, Emitter<PracticeState> emit) {
    if (_startTime == null) return;
    final timeLeft = _startTime!.add(_examDuration).difference(DateTime.now());
    emit(state.copyWith(timeLeft: timeLeft));
    if (timeLeft.isNegative) {
      _timeSub?.cancel();
      _timeSub == null;
      add(FinalizeTest());
    }
  }

  void _onToggleMarkQuestion(ToggleMarkQuestion event, Emitter<PracticeState> emit) {
    if (state.markedQuestions.contains(event.index)) {
      emit(state.copyWith(markedQuestions: {...state.markedQuestions}..remove(event.index)));
    } else {
      emit(state.copyWith(markedQuestions: {...state.markedQuestions, event.index}));
    }
  }

  void _onNavigateToQuestion(NavigateToQuestion event, Emitter<PracticeState> emit) {
    _navigateToIndex(event.index, emit);
  }
}

sealed class PracticeEvent {}

class NextQuestion extends PracticeEvent {}

class Init extends PracticeEvent {}

class PrevQuestion extends PracticeEvent {}

class FinalizeTest extends PracticeEvent {}

class MoveToQuestion extends PracticeEvent {
  int qid;

  MoveToQuestion(this.qid);
}

class AddAnswer extends PracticeEvent {
  int qid;
  Set<Choice> answer;

  AddAnswer(this.qid, this.answer);
}

class TimerTick extends PracticeEvent {}

class ToggleMarkQuestion extends PracticeEvent {
  final int index;

  ToggleMarkQuestion(this.index);
}

class NavigateToQuestion extends PracticeEvent {
  final int index;

  NavigateToQuestion(this.index);
}

@freezed
sealed class PracticeState with _$PracticeState {
  const factory PracticeState({
    @Default([]) List<int> questions,
    @Default(0) int currentQuestionIndex,
    @Default({}) Map<int, Set<Choice>> answers,
    @Default(0) int wrongAnswers,
    @Default(0) int rightAnswers,
    @Default(0) int score,
    @Default(0) int possibleScore,
    @Default(false) bool finalizeTest,
    Question? currentQuestion,
    Set<Choice>? currentAnswers,
    @Default(_examDuration) Duration timeLeft,
    @Default({}) Set<int> markedQuestions,
    @Default(false) timeout,
  }) = _PracticeState;
}
