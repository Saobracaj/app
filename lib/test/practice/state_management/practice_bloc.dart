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
///
/// Та же симуляция идёт и на других устройствах пользователя: снимки,
/// пришедшие оттуда ([PausedSimulationChange.remote], через
/// `SimulationSyncService`), блок применяет на лету — тот же вопрос, ответы,
/// отметки на страницах ([SelectionChanged]) и раскрытые ответы
/// ([AnswersRevealed]), пауза и остаток времени ([RemoteChangeReceived]).
/// Пока последнее изменение пришло с другого устройства, это устройство —
/// «зеркало»: его автоматические паузы (уход в фон, бездействие) не
/// действуют, иначе свёрнутый телефон в кармане останавливал бы экзамен на
/// вебе. Первое же действие пользователя здесь делает зеркалом остальные.
/// Экран результата или брошенной симуляции тоже слушает: новая симуляция,
/// начатая на другом устройстве, открывается на его месте.
class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  late QuestionsData data;
  final PracticeParams params;

  final PausedSimulationRepository _snapshots;
  final PausedSimulation? _snapshot;
  final bool _snapshotIsRemote;
  final bool _resume;
  final Duration? _idleTimeout;

  /// Идентификатор попытки (см. [PausedSimulation.attemptUuid]).
  String? _attemptUuid;

  /// Последнее изменение хода пришло с другого устройства, и пользователь
  /// с тех пор здесь ничего не делал.
  bool _remoteControlled = false;

  StreamSubscription<PausedSimulationChange>? _remoteSub;

  /// Банк как он есть в ассетах, до перетасовки вариантов — по нему снимок
  /// кодирует порядок вариантов и ответы индексами.
  final Map<int, Question> _bank;

  DateTime? _startedAt;

  /// Экзаменационное время, набежавшее до текущего отрезка работы.
  Duration _elapsedBeforePause = Duration.zero;

  /// Начало текущего отрезка работы; `null`, пока симуляция на паузе или ещё
  /// не начата.
  DateTime? _runningSince;

  /// Когда поставлена на паузу; `null`, пока идёт. Уходит в снимок, чтобы
  /// действие на паузе (например, ответ, доехавший с другого устройства) не
  /// записало симуляцию как идущую.
  DateTime? _pausedAt;
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
       _snapshotIsRemote = snapshot != null && snapshots.currentIsRemote,
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
    on<RemoteChangeReceived>(_onRemoteChange);
    on<SelectionChanged>(_onSelectionChanged);
    on<AnswersRevealed>(_onAnswersRevealed);

    _remoteSub = snapshots.events
        .where((change) => change.remote)
        .listen((change) => add(RemoteChangeReceived(change)));
    _watchLifecycle = watchLifecycle;
    _startTicking();
  }

  bool _watchLifecycle = true;

  /// Заводит секундный таймер и слушатель жизненного цикла — при старте и
  /// когда на месте оконченной симуляции открывается новая с другого
  /// устройства.
  void _startTicking() {
    _timeSub ??= Stream.periodic(
      Duration(seconds: 1),
    ).listen((event) => add(TimerTick()));
    if (_watchLifecycle) {
      // Свернули приложение / ушли с вкладки — симуляция встаёт на паузу.
      // Возобновление только по кнопке: вернувшись, пользователь сперва
      // видит экран паузы.
      // И onHide, и onPause: без известного предыдущего состояния слушатель
      // не достраивает промежуточные переходы и зовёт только конечный.
      _lifecycle ??= AppLifecycleListener(
        onHide: () => add(PauseRequested(automatic: true)),
        onPause: () => add(PauseRequested(automatic: true)),
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
    // Записанный ответ и есть выбор на странице.
    emit(
      state.copyWith(
        selections: {...state.selections, event.qid: event.answer},
      ),
    );
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
      _restore(snapshot, emit, remote: _snapshotIsRemote, resume: _resume);
      return;
    }
    // Снимок от другого банка вопросов (обновление приложения) продолжить
    // нельзя — стираем и начинаем заново. Чужой (с другого устройства) не
    // стираем: «стёрт» ушло бы туда как «брошена»; новая симуляция просто
    // перепишет его.
    if (snapshot != null && !_snapshotIsRemote) _snapshots.clear();
    _attemptUuid = genRecordId();
    final questions = data.practice[Random().nextInt(data.practice.length)];
    emit(state.copyWith(questions: questions));
    _recalculateState(state.answers, emit);
    _navigateToIndex(0, emit);
    final now = clock.now();
    _startedAt = now;
    _runningSince = now;
    _pausedAt = null;
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
  ///
  /// Снимок с другого устройства ([remote]), записанный на ходу
  /// (`pausedAt == null`), там и сейчас идёт: время, прошедшее с записи,
  /// тоже израсходовано, и открывается он на ходу независимо от [resume] —
  /// иначе перезагрузка вкладки ставила бы на паузу экзамен на телефоне.
  /// Чужой снимок, который здесь лишь отражают (идёт там или стоит на паузе
  /// без «продолжить»), обратно не отправляется — он не менялся.
  void _restore(
    PausedSimulation snapshot,
    Emitter<PracticeState> emit, {
    required bool remote,
    required bool resume,
  }) {
    // Варианты стоят так, как их видят там: у снимка с другого устройства
    // порядок мог разойтись с тем, что этот блок натасовал при создании.
    if (remote) _reorderChoices(snapshot.choiceOrder);
    final answers = _decodeChoices(snapshot.answers);
    emit(
      state.copyWith(
        questions: snapshot.questions,
        markedQuestions: snapshot.markedQuestions.toSet(),
        // Снимок без выбора (старая версия там): выбор равен ответам.
        selections: snapshot.selections.isEmpty
            ? answers
            : _decodeChoices(snapshot.selections),
        revealed: snapshot.revealed.toSet(),
        startedAt: snapshot.startedAt,
      ),
    );
    _recalculateState(answers, emit);
    _navigateToIndex(
      snapshot.currentQuestionIndex.clamp(0, snapshot.questions.length - 1),
      emit,
    );
    _startedAt = snapshot.startedAt;
    _attemptUuid = snapshot.attemptUuid ?? _attemptUuid ?? genRecordId();
    final now = clock.now();
    final runningElsewhere = remote && snapshot.pausedAt == null;
    _elapsedBeforePause =
        Duration(seconds: snapshot.elapsedSeconds) +
        (runningElsewhere ? _sinceSaved(snapshot, now) : Duration.zero);
    _lastActivity = now;
    final mirror = remote && (runningElsewhere || !resume);
    _remoteControlled = mirror;
    if (resume || runningElsewhere) {
      _runningSince = now;
      _pausedAt = null;
      emit(state.copyWith(paused: false, timeLeft: kExamDuration - _elapsed));
      if (!mirror) _persist();
    } else {
      // Открыли симуляцию без «продолжить» (перезагрузка вкладки, прямая
      // ссылка): она стоит на паузе, пока пользователь сам её не возобновит.
      _runningSince = null;
      _pausedAt = snapshot.pausedAt ?? now;
      emit(state.copyWith(paused: true, timeLeft: kExamDuration - _elapsed));
      if (!mirror) _persist();
    }
  }

  /// Индексы вариантов из снимка → варианты банка (вопросы, которых в банке
  /// нет, пропускаются — [_usable] такие снимки и так не пускает).
  Map<int, Set<Choice>> _decodeChoices(Map<int, List<int>> encoded) => {
    for (final entry in encoded.entries)
      if (_bank[entry.key] case final question?)
        entry.key: {for (final i in entry.value) question.choices[i]},
  };

  /// Переставляет варианты вопросов по [order] (id вопроса → индексы в
  /// исходном списке банка); вопросы, которых в [order] нет, не трогает.
  void _reorderChoices(Map<int, List<int>> order) {
    data = data.copyWith(
      questions: [
        for (final q in data.questions)
          if (order[q.id] case final indices?)
            q.copyWith(
              choices: [for (final i in indices) _bank[q.id]!.choices[i]],
            )
          else
            q,
      ],
    );
  }

  /// Сколько прошло с записи снимка на другом устройстве (по его часам —
  /// расхождение часов устройств принимаем за секунды, не минуты).
  Duration _sinceSaved(PausedSimulation snapshot, DateTime now) {
    final gap = now.difference(snapshot.savedAt);
    return gap.isNegative ? Duration.zero : gap;
  }

  /// Изменение хода с другого устройства: новый снимок применяется на лету,
  /// стёртый — заканчивает симуляцию и здесь так же, как там. На экране
  /// оконченной симуляции (результат, брошена) новый идущий снимок — это
  /// следующая симуляция, начатая там: открывается на его месте.
  Future<void> _onRemoteChange(
    RemoteChangeReceived event,
    Emitter<PracticeState> emit,
  ) async {
    if (_startedAt == null) return;
    final snapshot = event.change.snapshot;
    if (state.finalizeTest || state.abandoned) {
      if (snapshot == null ||
          snapshot.startedAt == _startedAt ||
          snapshot.pausedAt != null ||
          !_usable(snapshot)) {
        return;
      }
      _elapsedBeforePause = Duration.zero;
      _runningSince = null;
      _attemptUuid = null;
      emit(const PracticeState());
      _startTicking();
      _restore(snapshot, emit, remote: true, resume: false);
      return;
    }
    if (snapshot == null) {
      if (event.change.outcome == SimulationOutcome.finished) {
        // Тот же результат, что и там: ответы те же, попытка та же
        // (attemptUuid), бэкенд не запишет её дважды.
        await _finalize(emit);
      } else {
        _stop();
        emit(state.copyWith(abandoned: true, endedRemotely: true));
      }
      return;
    }
    // Снимок другого банка вопросов (там другая версия приложения) — не наш.
    if (!_usable(snapshot)) return;
    _restore(snapshot, emit, remote: true, resume: false);
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
  ) => _finalize(emit);

  Future<void> _finalize(Emitter<PracticeState> emit) async {
    _stop();

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
    // Assigned here rather than by the table's clientDefault so the result
    // screen knows the attempt's sync id — the Ask-AI chat about this exam is
    // keyed by it on the backend. Taken from the snapshot when there is one:
    // every device finishing this simulation records the same attempt.
    final attemptUuid = _attemptUuid ?? genRecordId();

    analytics.logSimulationFinished(
      durationSeconds: elapsed,
      points: pointsSummary,
      mistakes: wrongAnswers.length,
    );

    // Экзамен окончен — продолжать больше нечего (и на других устройствах:
    // они узнают об исходе через `SimulationSyncService`).
    _snapshots.clear(outcome: SimulationOutcome.finished);

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

  /// Останавливает таймер и слушатель жизненного цикла: симуляция окончена.
  /// Текущий отрезок работы засчитывается в экзаменационное время.
  void _stop() {
    _timeSub?.cancel();
    _timeSub = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _elapsedBeforePause = _elapsed;
    _runningSince = null;
  }

  @override
  Future<void> close() {
    _timeSub?.cancel();
    _lifecycle?.dispose();
    _remoteSub?.cancel();
    return super.close();
  }

  void _onTimerTick(TimerTick event, Emitter<PracticeState> emit) {
    if (_startedAt == null || state.paused || state.finalizeTest) return;
    final idle = _idleTimeout;
    // Зеркало не бездействует — действует пользователь на другом устройстве;
    // его таймер идёт дальше (иначе он застывал бы, пока там думают).
    if (idle != null &&
        !_remoteControlled &&
        clock.now().difference(_lastActivity) >= idle) {
      add(PauseRequested(automatic: true));
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
    // Зеркало чужого хода само не останавливает экзамен: пользователь
    // сейчас на другом устройстве.
    if (event.automatic && _remoteControlled) return;
    _elapsedBeforePause = _elapsed;
    _runningSince = null;
    _pausedAt = clock.now();
    _remoteControlled = false;
    emit(state.copyWith(paused: true, timeLeft: kExamDuration - _elapsed));
    _persist();
  }

  void _onResumeRequested(ResumeRequested event, Emitter<PracticeState> emit) {
    if (_startedAt == null || !state.paused || state.finalizeTest) return;
    final now = clock.now();
    _runningSince = now;
    _pausedAt = null;
    _lastActivity = now;
    _remoteControlled = false;
    emit(state.copyWith(paused: false, timeLeft: kExamDuration - _elapsed));
    _persist();
  }

  /// Выбор на странице вопроса изменился (тап по варианту — или доехавший
  /// туда чужой выбор: тогда он уже равен нашему и это пустой ход).
  void _onSelectionChanged(
    SelectionChanged event,
    Emitter<PracticeState> emit,
  ) {
    if (_startedAt == null || state.finalizeTest || state.abandoned) return;
    // Без выбора страница показывает записанный ответ — доклад о нём тоже
    // пустой ход (иначе зеркало приняло бы его за действие пользователя).
    final known = state.selections[event.qid] ?? state.answers[event.qid];
    if (setEquals(known, event.choices)) return;
    emit(
      state.copyWith(
        selections: {...state.selections, event.qid: event.choices},
      ),
    );
    _touch();
  }

  /// На странице показали верные ответы. Раскрытое не закрывается, поэтому
  /// повтор — пустой ход.
  void _onAnswersRevealed(AnswersRevealed event, Emitter<PracticeState> emit) {
    if (_startedAt == null || state.finalizeTest || state.abandoned) return;
    if (state.revealed.contains(event.qid)) return;
    emit(state.copyWith(revealed: {...state.revealed, event.qid}));
    _touch();
  }

  /// Пользователь бросил симуляцию с экрана паузы: результата нет, в
  /// статистику ничего не пишется, снимок стирается.
  void _onAbandonSimulation(
    AbandonSimulation event,
    Emitter<PracticeState> emit,
  ) {
    _stop();
    _snapshots.clear(outcome: SimulationOutcome.abandoned);
    emit(state.copyWith(abandoned: true));
  }

  /// Отмечает действие пользователя (ответ, переход, отметка) — от него
  /// отсчитывается автопауза по бездействию — и обновляет снимок.
  void _touch() {
    _lastActivity = clock.now();
    _remoteControlled = false;
    _persist();
  }

  void _persist() {
    final startedAt = _startedAt;
    if (startedAt == null || state.finalizeTest || state.abandoned) return;
    int originalIndex(int qid, Choice choice) =>
        _bank[qid]!.choices.indexOf(choice);
    Map<int, List<int>> encode(Map<int, Set<Choice>> choices) => {
      for (final entry in choices.entries)
        entry.key: [for (final c in entry.value) originalIndex(entry.key, c)],
    };
    final snapshot = PausedSimulation(
      startedAt: startedAt,
      elapsedSeconds: _elapsed.inSeconds,
      savedAt: clock.now(),
      pausedAt: _pausedAt,
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
      answers: encode(state.answers),
      selections: encode(state.selections),
      revealed: state.revealed.toList(),
      markedQuestions: state.markedQuestions.toList(),
      attemptUuid: _attemptUuid,
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
///
/// [automatic] — пауза не по воле пользователя (уход в фон, бездействие):
/// на устройстве, которое лишь зеркалит ход с другого, она не действует.
class PauseRequested extends PracticeEvent {
  PauseRequested({this.automatic = false});

  final bool automatic;
}

/// Снять с паузы: таймер идёт дальше с того же места.
class ResumeRequested extends PracticeEvent {}

/// Бросить симуляцию без результата (кнопка «завершить» на экране паузы).
class AbandonSimulation extends PracticeEvent {}

/// Ход симуляции изменился на другом устройстве (см.
/// [PausedSimulationRepository.events]).
class RemoteChangeReceived extends PracticeEvent {
  RemoteChangeReceived(this.change);

  final PausedSimulationChange change;
}

/// На странице вопроса [qid] отмечены [choices] (ещё не записанный ответ).
class SelectionChanged extends PracticeEvent {
  SelectionChanged(this.qid, this.choices);

  final int qid;
  final Set<Choice> choices;
}

/// На странице вопроса [qid] показаны верные ответы.
class AnswersRevealed extends PracticeEvent {
  AnswersRevealed(this.qid);

  final int qid;
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
    // Что отмечено на страницах вопросов (см. [SelectionChanged]); у
    // записанного ответа выбор равен ему.
    @Default({}) Map<int, Set<Choice>> selections,
    // Вопросы с показанными верными ответами (см. [AnswersRevealed]).
    @Default({}) Set<int> revealed,
    @Default(false) timeout,
    // Симуляция стоит на паузе: таймер не идёт, вместо вопроса — экран паузы.
    @Default(false) bool paused,
    // Пользователь бросил симуляцию с экрана паузы — результата не будет.
    @Default(false) bool abandoned,
    // Симуляцию бросили на другом устройстве: экран закрывается сам.
    @Default(false) bool endedRemotely,
    // Когда симуляция была начата (у продолженной — исходный старт).
    DateTime? startedAt,
  }) = _PracticeState;
}
