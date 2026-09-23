import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/auth_status.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/practice/data/paused_simulation_repository.dart';
import 'package:saobracaj/test/practice/data/simulation_sync_service.dart';
import 'package:saobracaj/test/practice/domain/paused_simulation.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Синхронизация идущей симуляции между устройствами (задача
/// 1218758215704610): снимок с другого устройства применяется к открытой
/// симуляции на лету (вопрос, ответы, отметки, время, пауза), зеркало не
/// ставит экзамен на паузу само, окончание там заканчивает симуляцию и
/// здесь; сервис отправляет местные изменения на бэкенд, принимает чужие
/// по подписке и просит открыть идущую симуляцию.

/// Три вопроса с одним верным ответом из двух.
QuestionsData _data() => QuestionsData(
  categories: const [],
  questions: [
    for (var id = 1; id <= 3; id++)
      Question(
        id: id,
        imageId: id,
        text: 'Питање број $id',
        choicesReq: 1,
        hasImage: false,
        points: 2,
        choices: [
          Choice(text: 'Тачан одговор $id', isCorrect: true),
          Choice(text: 'Нетачан одговор $id', isCorrect: false),
        ],
        categoryId: 'c',
        subcategoryId: 1,
      ),
  ],
  practice: const [
    [1, 2, 3],
  ],
);

Choice _correct(int id) => Choice(text: 'Тачан одговор $id', isCorrect: true);

PracticeBloc _bloc(
  PausedSimulationRepository snapshots, {
  PausedSimulation? snapshot,
  bool resume = false,
  Duration? idleTimeout,
}) => PracticeBloc(
  _data(),
  const PracticeParams(showRightAnswers: true),
  snapshots: snapshots,
  snapshot: snapshot,
  resume: resume,
  idleTimeout: idleTimeout,
  watchLifecycle: false,
);

Choice _wrong(int id) => Choice(text: 'Нетачан одговор $id', isCorrect: false);

/// Снимок, записанный на ходу на другом устройстве: второй вопрос, первый
/// отвечен верно, 10 минут экзамена прошло. [selections] / [revealed] —
/// что там отмечено на страницах и где раскрыты ответы.
PausedSimulation _remoteSnapshot({
  DateTime? savedAt,
  DateTime? pausedAt,
  DateTime? startedAt,
  String? attemptUuid = 'attempt-from-phone',
  int currentQuestionIndex = 1,
  Map<int, List<int>> selections = const {},
  List<int> revealed = const [],
}) => PausedSimulation(
  startedAt: startedAt ?? DateTime(2026, 9, 22, 21, 5),
  elapsedSeconds: 600,
  savedAt: savedAt ?? DateTime(2026, 9, 22, 21, 15),
  pausedAt: pausedAt,
  questions: const [1, 2, 3],
  currentQuestionIndex: currentQuestionIndex,
  choiceOrder: const {
    1: [1, 0],
    2: [0, 1],
    3: [1, 0],
  },
  answers: const {
    1: [0],
  },
  selections: selections,
  revealed: revealed,
  markedQuestions: const [2],
  attemptUuid: attemptUuid,
  showRightAnswers: true,
);

Future<void> _pump(WidgetTester tester, [int frames = 3]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}

/// Клиент, который записывает мутации и отвечает заранее заданным
/// результатом на запрос `simulation`.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  final List<(String, Map<String, dynamic>)> calls = [];
  Map<String, dynamic>? serverSimulation;

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    calls.add((query, variables));
    if (query.contains('query Simulation')) {
      return {'simulation': serverSimulation};
    }
    return const {};
  }
}

/// Подписка под управлением теста: события подсовываются через [events].
class _FakeSubscriptions extends GraphqlSubscriptionClient {
  _FakeSubscriptions(super.client, super.storage);

  final events = StreamController<GraphqlSubscriptionMessage>.broadcast();
  int subscriptions = 0;
  int reconnects = 0;

  @override
  Future<void> reconnect() async {
    reconnects++;
  }

  @override
  Stream<GraphqlSubscriptionMessage> subscribe(
    String query, {
    Map<String, dynamic> variables = const {},
  }) {
    subscriptions++;
    return events.stream;
  }
}

class _FakeAuth extends AuthRepository {
  _FakeAuth(GraphqlClient client, TokenStorage storage)
    : super(client, storage, AnalyticsService());

  final status = StreamController<AuthStatus>.broadcast();

  @override
  Stream<AuthStatus> get sessionStatus => status.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PausedSimulationRepository snapshots;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    snapshots = PausedSimulationRepository();
    getIt.registerSingleton<PausedSimulationRepository>(snapshots);
    getIt.registerSingleton<TokenStorage>(TokenStorage());
    getIt.registerSingleton<GraphqlClient>(
      GraphqlClient(getIt<TokenStorage>()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_sync').path,
        );
  });

  tearDown(() async {
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('PausedSimulationRepository', () {
    test('чужой снимок помечен как чужой и переживает перезапуск', () async {
      final events = <PausedSimulationChange>[];
      snapshots.events.listen(events.add);

      await snapshots.applyRemote(_remoteSnapshot());
      expect(snapshots.currentIsRemote, isTrue);
      expect(events.single.remote, isTrue);

      final restarted = PausedSimulationRepository();
      await restarted.bootstrap();
      expect(restarted.current?.attemptUuid, 'attempt-from-phone');
      expect(restarted.currentIsRemote, isTrue);

      await snapshots.save(_remoteSnapshot());
      expect(snapshots.currentIsRemote, isFalse);
      expect(events.last.remote, isFalse);

      await snapshots.clear(outcome: SimulationOutcome.finished);
      expect(events.last.snapshot, isNull);
      expect(events.last.remote, isFalse);
      expect(events.last.outcome, SimulationOutcome.finished);
    });
  });

  group('PracticeBloc', () {
    testWidgets('снимок с другого устройства применяется на лету: вопрос, '
        'ответы, отметки и время с учётом прошедшего с записи', (tester) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      expect(bloc.state.currentQuestionIndex, 0);
      final local = <PausedSimulationChange>[];
      snapshots.events.where((c) => !c.remote).listen(local.add);

      // Снимок записан там 20 секунд назад — эти секунды тоже прошли.
      final now = clock.now();
      await snapshots.applyRemote(
        _remoteSnapshot(savedAt: now.subtract(const Duration(seconds: 20))),
      );
      await _pump(tester);

      expect(bloc.state.currentQuestionIndex, 1);
      expect(bloc.state.currentQuestion?.id, 2);
      expect(bloc.state.answers[1], {_correct(1)});
      expect(bloc.state.markedQuestions, {2});
      expect(bloc.state.paused, isFalse);
      expect(
        bloc.state.timeLeft.inSeconds,
        closeTo(kExamDuration.inSeconds - 620, 2),
      );
      // Порядок вариантов — как там: у первого вопроса неверный первым.
      expect(
        bloc.data.questions
            .firstWhere((q) => q.id == 1)
            .choices
            .first
            .isCorrect,
        isFalse,
      );
      // Зеркало ничего не отправляет обратно.
      expect(local, isEmpty);

      // Таймер идёт дальше от чужого времени.
      await tester.pump(const Duration(seconds: 10));
      expect(
        bloc.state.timeLeft.inSeconds,
        closeTo(kExamDuration.inSeconds - 630, 2),
      );
      await tester.runAsync(bloc.close);
    });

    testWidgets('пауза с другого устройства останавливает таймер и здесь; '
        'зеркало само не ставит на паузу, а действие пользователя — ставит', (
      tester,
    ) async {
      final bloc = _bloc(snapshots, idleTimeout: const Duration(seconds: 30))
        ..add(Init());
      await _pump(tester);

      await snapshots.applyRemote(_remoteSnapshot(savedAt: clock.now()));
      await _pump(tester);
      // Автопауза по бездействию зеркала не действует: пользователь на
      // другом устройстве.
      await tester.pump(const Duration(seconds: 40));
      expect(bloc.state.paused, isFalse);
      bloc.add(PauseRequested(automatic: true));
      await _pump(tester);
      expect(bloc.state.paused, isFalse);

      // Там поставили на паузу — здесь тоже.
      await snapshots.applyRemote(
        _remoteSnapshot(savedAt: clock.now(), pausedAt: clock.now()),
      );
      await _pump(tester);
      expect(bloc.state.paused, isTrue);
      await tester.pump(const Duration(seconds: 30));
      expect(bloc.state.timeLeft, kExamDuration - const Duration(seconds: 600));

      // Тап «возобновить» здесь — своё действие, уходит на бэкенд.
      final local = <PausedSimulationChange>[];
      snapshots.events.where((c) => !c.remote).listen(local.add);
      bloc.add(ResumeRequested());
      await _pump(tester);
      expect(bloc.state.paused, isFalse);
      expect(local.single.snapshot?.pausedAt, isNull);
      expect(local.single.snapshot?.attemptUuid, 'attempt-from-phone');
      // После своего действия автопауза снова действует.
      bloc.add(PauseRequested(automatic: true));
      await _pump(tester);
      expect(bloc.state.paused, isTrue);
      await tester.runAsync(bloc.close);
    });

    testWidgets('отметка варианта на странице уходит в снимок; чужая отметка '
        'и раскрытие приходят в состояние, а их эхо не считается действием', (
      tester,
    ) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      final local = <PausedSimulationChange>[];
      snapshots.events.where((c) => !c.remote).listen(local.add);

      // Тап по варианту на первом вопросе (ещё не «следеће питање»).
      bloc.add(SelectionChanged(1, {_wrong(1)}));
      await _pump(tester);
      expect(bloc.state.selections[1], {_wrong(1)});
      expect(bloc.state.answers, isEmpty);
      expect(local.single.snapshot?.selections, {
        1: [1],
      });
      // Тот же выбор ещё раз (страница перестроилась) — ничего нового.
      bloc.add(SelectionChanged(1, {_wrong(1)}));
      await _pump(tester);
      expect(local, hasLength(1));

      // С другого устройства: на втором вопросе отмечен неверный, на первом
      // раскрыт ответ.
      await snapshots.applyRemote(
        _remoteSnapshot(
          savedAt: clock.now(),
          selections: const {
            1: [0],
            2: [1],
          },
          revealed: const [1],
        ),
      );
      await _pump(tester);
      expect(bloc.state.selections[2], {_wrong(2)});
      expect(bloc.state.selections[1], {_correct(1)});
      expect(bloc.state.revealed, {1});
      // Страницы докладывают то, что им подогнали, — зеркало остаётся
      // зеркалом и ничего не отправляет.
      bloc.add(SelectionChanged(2, {_wrong(2)}));
      bloc.add(SelectionChanged(1, {_correct(1)}));
      bloc.add(AnswersRevealed(1));
      await _pump(tester);
      expect(local, hasLength(1));
      bloc.add(PauseRequested(automatic: true));
      await _pump(tester);
      expect(bloc.state.paused, isFalse);

      // А новая отметка здесь — действие: уходит, и зеркалом становятся
      // остальные.
      bloc.add(SelectionChanged(2, {_correct(2)}));
      await _pump(tester);
      expect(local, hasLength(2));
      expect(local.last.snapshot?.selections[2], [0]);
      expect(local.last.snapshot?.revealed, [1]);
      expect(local.last.snapshot?.pausedAt, isNull);
      await tester.runAsync(bloc.close);
    });

    testWidgets('снимок без выбора (старая версия там): выбор равен ответам', (
      tester,
    ) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      await snapshots.applyRemote(_remoteSnapshot(savedAt: clock.now()));
      await _pump(tester);
      expect(bloc.state.selections, {
        1: {_correct(1)},
      });
      await tester.runAsync(bloc.close);
    });

    testWidgets('таймер зеркала идёт и после срока автопаузы по бездействию', (
      tester,
    ) async {
      final bloc = _bloc(snapshots, idleTimeout: const Duration(seconds: 30))
        ..add(Init());
      await _pump(tester);
      await snapshots.applyRemote(_remoteSnapshot(savedAt: clock.now()));
      await _pump(tester);
      final before = bloc.state.timeLeft;
      await tester.pump(const Duration(seconds: 60));
      expect(bloc.state.paused, isFalse);
      expect(
        before.inSeconds - bloc.state.timeLeft.inSeconds,
        inInclusiveRange(58, 61),
      );
      await tester.runAsync(bloc.close);
    });

    testWidgets('на экране результата новая симуляция с другого устройства '
        'открывается на его месте', (tester) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      await tester.runAsync(() => repository.getPracticeRecords());
      bloc.add(FinalizeTest());
      await _pump(tester);
      expect(bloc.state.finalizeTest, isTrue);

      // Старый снимок той же симуляции — не наш случай.
      await snapshots.applyRemote(
        _remoteSnapshot(savedAt: clock.now(), startedAt: bloc.state.startedAt),
      );
      await _pump(tester);
      expect(bloc.state.finalizeTest, isTrue);

      // Пауза там — баннера достаточно.
      await snapshots.applyRemote(
        _remoteSnapshot(savedAt: clock.now(), pausedAt: clock.now()),
      );
      await _pump(tester);
      expect(bloc.state.finalizeTest, isTrue);

      final next = _remoteSnapshot(
        savedAt: clock.now(),
        attemptUuid: 'next-attempt',
        currentQuestionIndex: 2,
      );
      await snapshots.applyRemote(next);
      await _pump(tester);
      expect(bloc.state.finalizeTest, isFalse);
      expect(bloc.state.attemptSaved, isFalse);
      expect(bloc.state.paused, isFalse);
      expect(bloc.state.currentQuestionIndex, 2);
      expect(bloc.state.startedAt, next.startedAt);
      expect(bloc.state.answers[1], {_correct(1)});
      // Таймер снова идёт.
      final before = bloc.state.timeLeft;
      await tester.pump(const Duration(seconds: 5));
      expect(before.inSeconds - bloc.state.timeLeft.inSeconds, closeTo(5, 1));
      // Завершение здесь пишет новую попытку, не старую.
      final local = <PausedSimulationChange>[];
      snapshots.events.where((c) => !c.remote).listen(local.add);
      bloc.add(FinalizeTest());
      await _pump(tester);
      expect(bloc.state.attemptUuid, 'next-attempt');
      expect(local.single.outcome, SimulationOutcome.finished);
    });

    testWidgets('окончание на другом устройстве: «брошена» закрывает экран, '
        '«завершена» показывает тот же результат той же попыткой', (
      tester,
    ) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      await snapshots.applyRemote(_remoteSnapshot(savedAt: clock.now()));
      await _pump(tester);
      await snapshots.applyRemote(null, outcome: SimulationOutcome.abandoned);
      await _pump(tester);
      expect(bloc.state.abandoned, isTrue);
      expect(bloc.state.endedRemotely, isTrue);
      expect(bloc.state.finalizeTest, isFalse);
      await tester.runAsync(bloc.close);

      final finished = _bloc(snapshots)..add(Init());
      await _pump(tester);
      // Открываем базу заранее, вне FakeAsync: завершение пишет в неё
      // попытку, а таймеры открытия Drift иначе повисли бы до конца теста.
      await tester.runAsync(() => repository.getPracticeRecords());
      await snapshots.applyRemote(_remoteSnapshot(savedAt: clock.now()));
      await _pump(tester);
      await snapshots.applyRemote(null, outcome: SimulationOutcome.finished);
      await _pump(tester);
      expect(finished.state.finalizeTest, isTrue);
      expect(finished.state.attemptUuid, 'attempt-from-phone');
      expect(finished.state.finalPoints, 2);
      // Время попытки — как там: 10 минут, набежавших до снимка.
      expect(finished.state.elapsedSeconds, closeTo(600, 2));
      // Блок не закрываем: завершение ждёт записи в базу (см. тест паузы).
    });

    testWidgets('чужой идущий снимок из хранилища открывается на ходу даже '
        'без «продолжить» и не отправляется обратно', (tester) async {
      await snapshots.applyRemote(_remoteSnapshot(savedAt: clock.now()));
      final local = <PausedSimulationChange>[];
      snapshots.events.where((c) => !c.remote).listen(local.add);
      final bloc = _bloc(snapshots, snapshot: snapshots.current)..add(Init());
      await _pump(tester);
      expect(bloc.state.paused, isFalse);
      expect(bloc.state.currentQuestionIndex, 1);
      expect(local, isEmpty);
      await tester.runAsync(bloc.close);
    });
  });

  group('SimulationSyncService', () {
    late _FakeClient client;
    late _FakeSubscriptions subscriptions;
    late _FakeAuth auth;
    late SimulationSyncService service;
    late String deviceId;

    setUp(() async {
      final storage = TokenStorage();
      deviceId = await storage.deviceId();
      client = _FakeClient(storage);
      subscriptions = _FakeSubscriptions(client, storage);
      auth = _FakeAuth(client, storage);
      service = SimulationSyncService(
        client,
        subscriptions,
        auth,
        snapshots,
        storage,
      );
      service.start();
      auth.status.add(AuthStatus.authenticated);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() => service.dispose());

    test('местные изменения уходят на бэкенд: снимок и исход', () async {
      expect(subscriptions.subscriptions, 1);
      await snapshots.save(_remoteSnapshot());
      await Future<void>.delayed(Duration.zero);
      final (set, variables) = client.calls.single;
      // Аргумент — переменная запроса, а не интерполированный Dart'ом объект
      // (второй литерал без `r` превращал `$snapshot` в `PausedSimulation(...)`,
      // и бэкенд отвечал ошибкой разбора).
      expect(set, contains(r'setSimulation(snapshot: $snapshot)'));
      expect(set, isNot(contains('PausedSimulation(')));
      final json = variables['snapshot'] as Map<String, dynamic>;
      expect(json['attemptUuid'], 'attempt-from-phone');
      expect(json['currentQuestionIndex'], 1);

      await snapshots.clear(outcome: SimulationOutcome.finished);
      await Future<void>.delayed(Duration.zero);
      final (clear, outcome) = client.calls.last;
      expect(clear, contains(r'clearSimulation(outcome: $outcome)'));
      expect(clear, isNot(contains('SimulationOutcome.')));
      expect(outcome['outcome'], 'FINISHED');
    });

    test('чужое событие кладётся в хранилище и просит открыть идущую '
        'симуляцию; своё эхо пропускается', () async {
      final opens = <PausedSimulation>[];
      service.openRequests.listen(opens.add);

      subscriptions.events.add(
        GraphqlSubscriptionData({
          'simulationChanged': {
            'snapshot': _remoteSnapshot().toJson(),
            'outcome': null,
            'deviceId': deviceId,
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.current, isNull);

      subscriptions.events.add(
        GraphqlSubscriptionData({
          'simulationChanged': {
            'snapshot': _remoteSnapshot().toJson(),
            'outcome': null,
            'deviceId': 'phone',
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.currentIsRemote, isTrue);
      expect(opens.single.attemptUuid, 'attempt-from-phone');
      // Чужое не отправляется обратно.
      expect(client.calls, isEmpty);

      // Пауза там — без открытия здесь.
      subscriptions.events.add(
        GraphqlSubscriptionData({
          'simulationChanged': {
            'snapshot': _remoteSnapshot(pausedAt: DateTime(2026)).toJson(),
            'outcome': null,
            'deviceId': 'phone',
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(opens, hasLength(1));
      expect(snapshots.current?.pausedAt, isNotNull);

      subscriptions.events.add(
        GraphqlSubscriptionData({
          'simulationChanged': {
            'snapshot': null,
            'outcome': 'FINISHED',
            'deviceId': 'phone',
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.current, isNull);
    });

    test('сверка после подключения: чужой снимок с бэкенда применяется, '
        'а свой, начатый без связи, отправляется', () async {
      client.serverSimulation = {
        'snapshot': _remoteSnapshot().toJson(),
        'deviceId': 'phone',
        'updatedAt': '2026-09-22T21:15:00Z',
      };
      subscriptions.events.add(
        const GraphqlSubscriptionResumed(firstConnect: true),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.currentIsRemote, isTrue);
      expect(client.calls.single.$1, contains('query Simulation'));

      // Свой более свежий снимок и пусто на бэкенде — уходит наш.
      client.calls.clear();
      client.serverSimulation = null;
      await snapshots.save(_remoteSnapshot(savedAt: clock.now()));
      await Future<void>.delayed(Duration.zero);
      client.calls.clear();
      subscriptions.events.add(
        const GraphqlSubscriptionResumed(firstConnect: false),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(client.calls.map((c) => c.$1), [
        contains('query Simulation'),
        contains('setSimulation'),
      ]);
    });

    test('надгробие на бэкенде: снимок той же попытки стёрт с тем же исходом, '
        'своя другая попытка — отправлена', () async {
      final events = <PausedSimulationChange>[];
      snapshots.events.listen(events.add);
      // Свой снимок, но экзамен закончили на другом устройстве, пока нас не
      // было: стирается, а не воскрешается на бэкенде.
      await snapshots.save(_remoteSnapshot(savedAt: clock.now()));
      await Future<void>.delayed(Duration.zero);
      client.calls.clear();
      client.serverSimulation = {
        'snapshot': _remoteSnapshot().toJson(),
        'outcome': 'FINISHED',
        'deviceId': 'web',
        'updatedAt': '2026-09-22T21:30:00Z',
      };
      subscriptions.events.add(
        const GraphqlSubscriptionResumed(firstConnect: false),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.current, isNull);
      expect(events.last.remote, isTrue);
      expect(events.last.outcome, SimulationOutcome.finished);
      expect(client.calls.map((c) => c.$1), [contains('query Simulation')]);

      // Надгробие без снимка (там закончили то, что не успели отправить) —
      // тоже конец нашей копии.
      await snapshots.applyRemote(_remoteSnapshot());
      client.calls.clear();
      client.serverSimulation = {
        'snapshot': null,
        'outcome': 'ABANDONED',
        'deviceId': 'web',
        'updatedAt': '2026-09-22T21:31:00Z',
      };
      subscriptions.events.add(
        const GraphqlSubscriptionResumed(firstConnect: false),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.current, isNull);
      expect(events.last.outcome, SimulationOutcome.abandoned);

      // Своя новая попытка, начатая без связи после того конца, — уходит.
      await snapshots.save(
        _remoteSnapshot(savedAt: clock.now(), attemptUuid: 'started-offline'),
      );
      await Future<void>.delayed(Duration.zero);
      client.calls.clear();
      client.serverSimulation = {
        'snapshot': _remoteSnapshot().toJson(),
        'outcome': 'FINISHED',
        'deviceId': 'web',
        'updatedAt': '2026-09-22T21:32:00Z',
      };
      subscriptions.events.add(
        const GraphqlSubscriptionResumed(firstConnect: false),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.current?.attemptUuid, 'started-offline');
      expect(client.calls.map((c) => c.$1), [
        contains('query Simulation'),
        contains('setSimulation'),
      ]);
    });

    test(
      'ответ сверки старее уже применённого события не откатывает его',
      () async {
        subscriptions.events.add(
          GraphqlSubscriptionData({
            'simulationChanged': {
              'snapshot': _remoteSnapshot(currentQuestionIndex: 2).toJson(),
              'outcome': null,
              'deviceId': 'phone',
              'updatedAt': '2026-09-22T21:20:00Z',
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(snapshots.current?.currentQuestionIndex, 2);

        client.serverSimulation = {
          'snapshot': _remoteSnapshot(currentQuestionIndex: 1).toJson(),
          'deviceId': 'phone',
          'updatedAt': '2026-09-22T21:19:00Z',
        };
        subscriptions.events.add(
          const GraphqlSubscriptionResumed(firstConnect: false),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(snapshots.current?.currentQuestionIndex, 2);

        // Событие старее последнего — тоже мимо; свежее — применяется.
        subscriptions.events.add(
          GraphqlSubscriptionData({
            'simulationChanged': {
              'snapshot': _remoteSnapshot(currentQuestionIndex: 0).toJson(),
              'outcome': null,
              'deviceId': 'phone',
              'updatedAt': '2026-09-22T21:18:00Z',
            },
          }),
        );
        subscriptions.events.add(
          GraphqlSubscriptionData({
            'simulationChanged': {
              'snapshot': _remoteSnapshot(currentQuestionIndex: 1).toJson(),
              'outcome': null,
              'deviceId': 'phone',
              'updatedAt': '2026-09-22T21:21:00Z',
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(snapshots.current?.currentQuestionIndex, 1);
      },
    );

    test('возврат приложения из фона переоткрывает сокет', () async {
      final binding = TestWidgetsFlutterBinding.instance;
      // Системный диалог поверх (inactive → resumed) — не повод.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(subscriptions.reconnects, 0);

      // Ушли в фон и вернулись — переходы, как их достраивает платформа.
      void background() {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }

      void foreground() {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }

      background();
      foreground();
      await Future<void>.delayed(Duration.zero);
      expect(subscriptions.reconnects, 1);

      // Гость (вышли) — сокета нет, переоткрывать нечего.
      auth.status.add(AuthStatus.unauthenticated);
      await Future<void>.delayed(Duration.zero);
      background();
      foreground();
      await Future<void>.delayed(Duration.zero);
      expect(subscriptions.reconnects, 1);
    });

    test('сверка: на бэкенде пусто, а здесь чужой снимок — он стёрт', () async {
      await snapshots.applyRemote(_remoteSnapshot());
      client.serverSimulation = null;
      subscriptions.events.add(
        const GraphqlSubscriptionResumed(firstConnect: true),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.current, isNull);
    });
  });
}
