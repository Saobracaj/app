import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/db/answer_table.dart' show genRecordId;
import 'package:saobracaj/db/db.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/practice/data/paused_simulation_repository.dart';
import 'package:saobracaj/test/practice/domain/paused_simulation.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';

part 'practice_bloc.freezed.dart';

/// Длительность теоретического экзамена.
const kExamDuration = Duration(minutes: 45);

/// Через сколько бездействия (ни ответа, ни перехода между вопросами)
/// симуляция сама встаёт на паузу. Только на вебе: на телефоне уход из
/// приложения виден по жизненному циклу, а вкладку браузера можно просто
/// забыть открытой.
const Duration? _defaultIdleTimeout = kIsWeb ? Duration(minutes: 3) : null;

/// Ход одной симуляции экзамена: вопросы варианта, ответы, отметки, таймер.
///
/// Пауза ([PauseRequested]) останавливает таймер; экзаменационное время
/// считается как сумма отрезков, когда симуляция шла. Снимок хода
/// ([PausedSimulation]) пишется в [PausedSimulationRepository] после каждого
/// действия и при паузе, так что продолжить можно и после сворачивания, и
/// после убийства приложения; по завершении экзамена снимок стирается.
class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  late QuestionsData data;
  final PracticeParams params;

  final PausedSimulationRepository _snapshots;
  final PausedSimulation? _snapshot;
  final bool _resume;
  final Duration? _idleTimeout;

  /// Банк как он есть в ассетах, до перетасовки вариантов — по нему снимок
  /// кодирует порядок вариантов и ответы индексами.
  final Map<int, Question> _bank;

  DateTime? _startedAt;

  /// Экзаменационное время, набежавшее до текущего отрезка работы.
  Duration _elapsedBeforePause = Duration.zero;

  /// Начало текущего отрезка работы; `null`, пока симуляция на паузе или ещё
  /// не начата.
  DateTime? _runningSince;
  DateTime _lastActivity = clock.now();

  StreamSubscription? _timeSub;
  AppLifecycleListener? _lifecycle;

  /// [snapshot] — незавершённая симуляция, которую нужно продолжить вместо
  /// новой; [resume] — сразу запустить таймер (переход по кнопке
  /// «продолжить»), иначе она откроется на экране паузы. [idleTimeout] —
  /// автопауза по бездействию (по умолчанию 3 минуты на вебе, на других
  /// платформах выключена); [watchLifecycle] — ставить паузу, когда приложение
  /// уходит в фон.
  PracticeBloc(
    QuestionsData data,
    this.params, {
    required PausedSimulationRepository snapshots,
    PausedSimulation? snapshot,
    bool resume = false,
    Duration? idleTimeout = _defaultIdleTimeout,
    bool watchLifecycle = true,
  }) : _snapshots = snapshots,
       _snapshot = snapshot,
       _resume = resume,
       _idleTimeout = idleTimeout,
       _bank = {for (final q in data.questions) q.id: q},
       super(PracticeState()) {
    final questions = <Question>[];
    for (var q in data.questions) {
      final order = snapshot?.choiceOrder[q.id];
      // У продолжаемой симуляции варианты стоят так, как их уже видел
      // пользователь; у новой — тасуются заново.
      final choices = order == null
          ? ([...q.choices]..shuffle())
          : [for (final i in order) q.choices[i]];
      questions.add(q.copyWith(choices: choices));
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
    on<PauseRequested>(_onPauseRequested);
    on<ResumeRequested>(_onResumeRequested);
    on<AbandonSimulation>(_onAbandonSimulation);

    _timeSub = Stream.periodic(
      Duration(seconds: 1),
    ).listen((event) => add(TimerTick()));
    if (watchLifecycle) {
      // Свернули приложение / ушли с вкладки — симуляция встаёт на паузу.
      // Возобновление только по кнопке: вернувшись, пользователь сперва
      // видит экран паузы.
      // И onHide, и onPause: без известного предыдущего состояния слушатель
      // не достраивает промежуточные переходы и зовёт только конечный.
      _lifecycle = AppLifecycleListener(
        onHide: () => add(PauseRequested()),
        onPause: () => add(PauseRequested()),
      );
    }
  }

  /// Экзаменационное время с начала симуляции без учёта пауз.
  Duration get _elapsed {
    final since = _runningSince;
    return since == null
        ? _elapsedBeforePause
        : _elapsedBeforePause + clock.now().difference(since);
  }

  void _onNextQuestion(NextQuestion event, Emitter<PracticeState> emit) {
    final nextIndex = state.currentQuestionIndex + 1;
    if (nextIndex >= state.questions.length) return;
    _navigateToIndex(nextIndex, emit);
    _touch();
  }

  void _onPrevQuestion(PrevQuestion event, Emitter<PracticeState> emit) {
    final nextIndex = state.currentQuestionIndex - 1;
    if (nextIndex < 0) return;
    _navigateToIndex(nextIndex, emit);
    _touch();
  }

  void _navigateToIndex(int index, Emitter<PracticeState> emit) {
    final curQuestion = data.questions.firstWhere(
      (element) => element.id == state.questions[index],
    );
    final curAnswers = state.answers[curQuestion.id];
    emit(
      state.copyWith(
        currentQuestionIndex: index,
        currentQuestion: curQuestion,
        currentAnswers: curAnswers,
      ),
    );
  }

  void _onAddAnswer(AddAnswer event, Emitter<PracticeState> emit) {
    final answers = {...state.answers};
    answers[event.qid] = event.answer;
    _recalculateState(answers, emit);
    _touch();

    final question = data.questions.firstWhere(
      (element) => element.id == event.qid,
    );
    final correctAnswers = question.choices
        .where((element) => element.isCorrect)
        .toSet();
    final correct = setEquals(correctAnswers, event.answer);

    // Same event as a quiz run's answer, so PostHog's answer counts match the
    // local history (`answer_records`), which stores exam answers too.
    analytics.logQuestionAnswered(
      questionId: event.qid,
      correct: correct,
      mode: 'exam',
    );

    repository.addAnswer(event.qid, !correct);
  }

  void _recalculateState(
    Map<int, Set<Choice>> answers,
    Emitter<PracticeState> emit,
  ) {
    var score = 0;
    var wrong = 0;
    var right = 0;
    var possibleScore = 0;

    for (var qid in state.questions) {
      final question = data.questions.firstWhere(
        (element) => element.id == qid,
      );
      possibleScore += question.points;
    }

    for (var answer in answers.entries) {
      final question = data.questions.firstWhere(
        (element) => element.id == answer.key,
      );
      final correctAnswers = question.choices
          .where((element) => element.isCorrect)
          .toSet();

      if (setEquals(correctAnswers, answer.value)) {
        // answer is correct
        right++;
        score += question.points;
      } else {
        wrong++;
      }
    }

    emit(
      state.copyWith(
        score: score,
        wrongAnswers: wrong,
        rightAnswers: right,
        possibleScore: possibleScore,
        answers: answers,
      ),
    );
  }

  void _onInit(Init event, Emitter<PracticeState> emit) {
    final snapshot = _snapshot;
    if (snapshot != null && _usable(snapshot)) {
      _restore(snapshot, emit);
      return;
    }
    // Снимок от другого банка вопросов (обновление приложения) продолжить
    // нельзя — стираем и начинаем заново.
    if (snapshot != null) _snapshots.clear();
    final questions = data.practice[Random().nextInt(data.practice.length)];
    emit(state.copyWith(questions: questions));
    _recalculateState(state.answers, emit);
    _navigateToIndex(0, emit);
    final now = clock.now();
    _startedAt = now;
    _runningSince = now;
    _lastActivity = now;
    emit(state.copyWith(startedAt: now));
    analytics.logSimulationStarted();
    _persist();
  }

  /// Снимок собран по этому же банку: все вопросы и индексы вариантов на
  /// месте.
  bool _usable(PausedSimulation snapshot) {
    if (snapshot.questions.isEmpty) return false;
    for (final qid in snapshot.questions) {
      final question = _bank[qid];
      if (question == null) return false;
      final order = snapshot.choiceOrder[qid] ?? const [];
      final answer = snapshot.answers[qid] ?? const [];
      if ([
        ...order,
        ...answer,
      ].any((i) => i < 0 || i >= question.choices.length)) {
        return false;
      }
    }
    return true;
  }

  /// Поднимает ход симуляции из снимка: тот же вариант, те же ответы и
  /// отметки, тот же текущий вопрос и столько же оставшегося времени.
  void _restore(PausedSimulation snapshot, Emitter<PracticeState> emit) {
    final answers = <int, Set<Choice>>{
      for (final entry in snapshot.answers.entries)
        if (_bank[entry.key] case final question?)
          entry.key: {for (final i in entry.value) question.choices[i]},
    };
    emit(
      state.copyWith(
        questions: snapshot.questions,
        markedQuestions: snapshot.markedQuestions.toSet(),
        startedAt: snapshot.startedAt,
      ),
    );
    _recalculateState(answers, emit);
    _navigateToIndex(
      snapshot.currentQuestionIndex.clamp(0, snapshot.questions.length - 1),
      emit,
    );
    _startedAt = snapshot.startedAt;
    _elapsedBeforePause = Duration(seconds: snapshot.elapsedSeconds);
    final now = clock.now();
    _lastActivity = now;
    if (_resume) {
      _runningSince = now;
      emit(state.copyWith(paused: false, timeLeft: kExamDuration - _elapsed));
      _persist();
    } else {
      // Открыли симуляцию без «продолжить» (перезагрузка вкладки, прямая
      // ссылка): она стоит на паузе, пока пользователь сам её не возобновит.
      emit(state.copyWith(paused: true, timeLeft: kExamDuration - _elapsed));
      _persist(pausedAt: snapshot.pausedAt ?? now);
    }
  }

  void _onMoveToQuestiont(MoveToQuestion event, Emitter<PracticeState> emit) {
    final ind = state.questions.indexOf(event.qid);
    emit(state.copyWith(currentQuestionIndex: ind));
    _touch();
  }

  // Future<void>, а не `void ... async`: обработчик доигрывает после await'а
  // записи в базу (см. emit `attemptSaved` ниже), и Bloc должен его дождаться —
  // иначе Emitter закрывается раньше, чем дело дойдёт до последнего emit.
  Future<void> _onFinalizeTest(
    FinalizeTest event,
    Emitter<PracticeState> emit,
  ) async {
    _timeSub?.cancel();
    _timeSub = null;
    _lifecycle?.dispose();
    _lifecycle = null;

    var pointsSummary = 0;
    final wrongAnswers = <int>[];
    final qs = data.questions;
    for (var a in state.questions) {
      final q = qs.firstWhere((element) => element.id == a);
      final answers = state.answers[q.id] ?? {};
      if (!setEquals(
        q.choices.where((element) => element.isCorrect).toSet(),
        answers,
      )) {
        wrongAnswers.add(q.id);
      } else {
        pointsSummary += q.points;
      }
    }
    final elapsed = _elapsed.inSeconds;
    _elapsedBeforePause = _elapsed;
    _runningSince = null;
    // Assigned here rather than by the table's clientDefault so the result
    // screen knows the attempt's sync id — the Ask-AI chat about this exam is
    // keyed by it on the backend.
    final attemptUuid = genRecordId();

    analytics.logSimulationFinished(
      durationSeconds: elapsed,
      points: pointsSummary,
      mistakes: wrongAnswers.length,
    );

    // Экзамен окончен — продолжать больше нечего.
    _snapshots.clear();

    // The result screen renders from these — the same numbers that go into
    // the practice record below.
    emit(
      state.copyWith(
        finalizeTest: true,
        paused: false,
        finalPoints: pointsSummary,
        finalWrongQuestions: wrongAnswers,
        elapsedSeconds: elapsed,
        attemptUuid: attemptUuid,
      ),
    );

    await repository.insertPracticeRecord(
      PracticeRecordsCompanion(
        points: Value(pointsSummary),
        time: Value(clock.now()),
        mistakes: Value(wrongAnswers.length),
        durationSeconds: Value(elapsed),
        wrongAnswers: Value(wrongAnswers),
        uuid: Value(attemptUuid),
      ),
    );
    // Только теперь запись экзамена лежит в practice_records — до этого момента
    // читать её бессмысленно. Флаг взводится отдельным emit'ом, потому что
    // экран результата открывается раньше, чем заканчивается запись в базу, а
    // автосписок «ошибки последнего экзамена» строится именно по ней.
    emit(state.copyWith(attemptSaved: true));

    // Push the new result to the back-end (no-op when signed out).
    statisticsSync.sync();
  }

  @override
  Future<void> close() {
    _timeSub?.cancel();
    _lifecycle?.dispose();
    return super.close();
  }

  void _onTimerTick(TimerTick event, Emitter<PracticeState> emit) {
    if (_startedAt == null || state.paused || state.finalizeTest) return;
    final idle = _idleTimeout;
    if (idle != null && clock.now().difference(_lastActivity) >= idle) {
      add(PauseRequested());
      return;
    }
    final timeLeft = kExamDuration - _elapsed;
    emit(state.copyWith(timeLeft: timeLeft));
    if (timeLeft.isNegative) {
      _timeSub?.cancel();
      _timeSub = null;
      add(FinalizeTest());
    }
  }

  void _onToggleMarkQuestion(
    ToggleMarkQuestion event,
    Emitter<PracticeState> emit,
  ) {
    if (state.markedQuestions.contains(event.index)) {
      emit(
        state.copyWith(
          markedQuestions: {...state.markedQuestions}..remove(event.index),
        ),
      );
    } else {
      emit(
        state.copyWith(
          markedQuestions: {...state.markedQuestions, event.index},
        ),
      );
    }
    _touch();
  }

  void _onNavigateToQuestion(
    NavigateToQuestion event,
    Emitter<PracticeState> emit,
  ) {
    _navigateToIndex(event.index, emit);
    _touch();
  }

  void _onPauseRequested(PauseRequested event, Emitter<PracticeState> emit) {
    if (_startedAt == null || state.paused || state.finalizeTest) return;
    final now = clock.now();
    _elapsedBeforePause = _elapsed;
    _runningSince = null;
    emit(state.copyWith(paused: true, timeLeft: kExamDuration - _elapsed));
    _persist(pausedAt: now);
  }

  void _onResumeRequested(ResumeRequested event, Emitter<PracticeState> emit) {
    if (_startedAt == null || !state.paused || state.finalizeTest) return;
    final now = clock.now();
    _runningSince = now;
    _lastActivity = now;
    emit(state.copyWith(paused: false, timeLeft: kExamDuration - _elapsed));
    _persist();
  }

  /// Пользователь бросил симуляцию с экрана паузы: результата нет, в
  /// статистику ничего не пишется, снимок стирается.
  void _onAbandonSimulation(
    AbandonSimulation event,
    Emitter<PracticeState> emit,
  ) {
    _timeSub?.cancel();
    _timeSub = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _runningSince = null;
    _snapshots.clear();
    emit(state.copyWith(abandoned: true));
  }

  /// Отмечает действие пользователя (ответ, переход, отметка) — от него
  /// отсчитывается автопауза по бездействию — и обновляет снимок.
  void _touch() {
    _lastActivity = clock.now();
    _persist();
  }

  void _persist({DateTime? pausedAt}) {
    final startedAt = _startedAt;
    if (startedAt == null || state.finalizeTest || state.abandoned) return;
    int originalIndex(int qid, Choice choice) =>
        _bank[qid]!.choices.indexOf(choice);
    final snapshot = PausedSimulation(
      startedAt: startedAt,
      elapsedSeconds: _elapsed.inSeconds,
      savedAt: clock.now(),
      pausedAt: pausedAt,
      questions: state.questions,
      currentQuestionIndex: state.currentQuestionIndex,
      choiceOrder: {
        for (final qid in state.questions)
          qid: [
            for (final c
                in data.questions.firstWhere((q) => q.id == qid).choices)
              originalIndex(qid, c),
          ],
      },
      answers: {
        for (final entry in state.answers.entries)
          entry.key: [for (final c in entry.value) originalIndex(entry.key, c)],
      },
      markedQuestions: state.markedQuestions.toList(),
      showRightAnswers: params.showRightAnswers,
      showStats: params.showStats,
      buttonsLikeInExam: params.buttonsLikeInExam,
    );
    _snapshots.save(snapshot);
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

/// Поставить симуляцию на паузу (тап по таймеру, уход в фон, бездействие).
class PauseRequested extends PracticeEvent {}

/// Снять с паузы: таймер идёт дальше с того же места.
class ResumeRequested extends PracticeEvent {}

/// Бросить симуляцию без результата (кнопка «завершить» на экране паузы).
class AbandonSimulation extends PracticeEvent {}

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
    // Запись попытки уже сохранена в practice_records: всё, что читает историю
    // экзаменов (автосписок «ошибки последнего экзамена»), ждёт этого момента.
    @Default(false) bool attemptSaved,
    // The authoritative final grading, set once at FinalizeTest: unanswered
    // questions count as wrong here, unlike the running score above.
    @Default(0) int finalPoints,
    @Default(<int>[]) List<int> finalWrongQuestions,
    // The finished attempt's sync uuid — the Ask-AI exam chat's scope id.
    String? attemptUuid,
    int? elapsedSeconds,
    Question? currentQuestion,
    Set<Choice>? currentAnswers,
    @Default(kExamDuration) Duration timeLeft,
    @Default({}) Set<int> markedQuestions,
    @Default(false) timeout,
    // Симуляция стоит на паузе: таймер не идёт, вместо вопроса — экран паузы.
    @Default(false) bool paused,
    // Пользователь бросил симуляцию с экрана паузы — результата не будет.
    @Default(false) bool abandoned,
    // Когда симуляция была начата (у продолженной — исходный старт).
    DateTime? startedAt,
  }) = _PracticeState;
}
