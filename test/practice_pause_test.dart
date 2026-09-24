import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/practice/data/paused_simulation_repository.dart';
import 'package:saobracaj/test/practice/domain/paused_simulation.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/state_management/paused_simulation_bloc.dart';
import 'package:saobracaj/test/practice/state_management/paused_simulation_events.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/practice/widgets/pause_screen.dart';
import 'package:saobracaj/test/practice/widgets/paused_simulation_banner.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Пауза и сохранение хода симуляции (задача 1218735977258537): тап по
/// таймеру, уход приложения в фон и бездействие на вебе ставят симуляцию на
/// паузу; ход пишется в снимок и поднимается из него с тем же вопросом,
/// ответами и остатком времени; на главной и странице запуска — баннер
/// «продолжить».

class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

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
Choice _wrong(int id) => Choice(text: 'Нетачан одговор $id', isCorrect: false);

/// Блок без слушателя жизненного цикла и без автопаузы, если не сказано иное.
PracticeBloc _bloc(
  PausedSimulationRepository snapshots, {
  PausedSimulation? snapshot,
  bool resume = false,
  Duration? idleTimeout,
  bool watchLifecycle = false,
}) => PracticeBloc(
  _data(),
  const PracticeParams(showRightAnswers: true),
  snapshots: snapshots,
  snapshot: snapshot,
  resume: resume,
  idleTimeout: idleTimeout,
  watchLifecycle: watchLifecycle,
);

Widget _localized(Widget child) => EasyLocalization(
  useOnlyLangCode: true,
  supportedLocales: const [Locale('ru')],
  fallbackLocale: const Locale('ru'),
  startLocale: const Locale('ru'),
  path: 'assets/translations',
  assetLoader: const CodegenLoader(),
  child: child,
);

/// Приложение с роутером: симуляция на `/questPractice`, главная и страница
/// запуска — заглушки с баннером, чтобы проверить переходы с экрана паузы.
Widget _app(
  PausedSimulationRepository snapshots, {
  String initialPath = '/questPractice',
}) => _localized(
  MultiBlocProvider(
    providers: [
      BlocProvider<AllQuestionsBloc>(
        create: (_) => _StubAllQuestionsBloc(_data()),
      ),
      BlocProvider(
        create: (_) => FeatureFlagsBloc(
          FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
        ),
      ),
      BlocProvider(
        create: (_) =>
            PausedSimulationBloc(snapshots)..add(PausedSimulationStarted()),
      ),
    ],
    child: Builder(
      builder: (context) => MaterialApp.router(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
        routerDelegate: RoutemasterDelegate(
          routesBuilder: (_) => RouteMap(
            routes: {
              '/': (_) => const Redirect('/home'),
              '/home': (_) => const MaterialPage(
                child: Scaffold(
                  body: Column(
                    children: [Text('главная'), PausedSimulationBanner()],
                  ),
                ),
              ),
              '/practice': (_) => const MaterialPage(
                child: Scaffold(
                  body: Column(
                    children: [
                      Text('страница запуска'),
                      PausedSimulationBanner(),
                    ],
                  ),
                ),
              ),
              '/questPractice': (data) => MaterialPage(
                child: Practice(
                  params: const PracticeParams(showRightAnswers: true),
                  resume: data.queryParameters['resume'] == 'true',
                ),
              ),
            },
          ),
        ),
        routeInformationParser: const RoutemasterParser(),
        routeInformationProvider: PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(
            uri: Uri.parse(initialPath),
          ),
        ),
      ),
    ),
  ),
);

/// Симуляция тикает секундным таймером, так что `pumpAndSettle` не сходится:
/// ждём явными кадрами. Закрывать блок — только через `tester.runAsync`:
/// под FakeAsync `Bloc.close()` не завершается.
Future<void> _pump(WidgetTester tester, [int frames = 3]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting('ru');
  });

  late PausedSimulationRepository snapshots;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    snapshots = PausedSimulationRepository();
    getIt.registerSingleton<PausedSimulationRepository>(snapshots);
    // Завершение экзамена дёргает синхронизацию статистики, а та берёт
    // клиент из getIt (без сессии — no-op).
    getIt.registerSingleton<TokenStorage>(TokenStorage());
    getIt.registerSingleton<GraphqlClient>(
      GraphqlClient(getIt<TokenStorage>()),
    );
    // Ответы пишутся в Drift, а Drift спрашивает у path_provider каталог —
    // подсовываем временный вместо нереализованного плагина.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_pause').path,
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

  group('PracticeBloc', () {
    testWidgets('пауза останавливает таймер, возобновление продолжает его', (
      tester,
    ) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      expect(bloc.state.startedAt, isNotNull);

      await tester.pump(const Duration(seconds: 10));
      expect(bloc.state.timeLeft, kExamDuration - const Duration(seconds: 10));

      bloc.add(PauseRequested());
      await _pump(tester);
      expect(bloc.state.paused, isTrue);
      // На паузе время экзамена не идёт.
      await tester.pump(const Duration(minutes: 5));
      expect(bloc.state.timeLeft, kExamDuration - const Duration(seconds: 10));
      // Снимок помечен паузой и хранит израсходованные секунды.
      expect(snapshots.current?.pausedAt, isNotNull);
      expect(snapshots.current?.elapsedSeconds, 10);

      bloc.add(ResumeRequested());
      await _pump(tester);
      expect(bloc.state.paused, isFalse);
      expect(snapshots.current?.pausedAt, isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(bloc.state.timeLeft, kExamDuration - const Duration(seconds: 15));

      await tester.runAsync(bloc.close);
    });

    testWidgets('снимок хранит ответы, отметки и текущий вопрос; из снимка '
        'симуляция поднимается в том же состоянии', (tester) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      bloc.add(AddAnswer(1, {_correct(1)}));
      bloc.add(NextQuestion());
      bloc.add(AddAnswer(2, {_wrong(2)}));
      bloc.add(ToggleMarkQuestion(1));
      bloc.add(NextQuestion());
      await _pump(tester);
      await tester.pump(const Duration(seconds: 42));
      bloc.add(PauseRequested());
      await _pump(tester);
      await tester.runAsync(bloc.close);

      final snapshot = snapshots.current!;
      expect(snapshot.questions, [1, 2, 3]);
      expect(snapshot.currentQuestionIndex, 2);
      expect(snapshot.markedQuestions, [1]);
      expect(snapshot.answers.keys, unorderedEquals([1, 2]));
      expect(snapshot.elapsedSeconds, 42);

      // Снимок переживает перезапуск: репозиторий читает его из хранилища.
      final reloaded = PausedSimulationRepository();
      await reloaded.bootstrap();
      expect(reloaded.current, snapshot);

      // Продолжение: те же ответы, тот же вопрос, тот же остаток времени.
      final resumed = _bloc(reloaded, snapshot: snapshot, resume: true)
        ..add(Init());
      await _pump(tester);
      expect(resumed.state.paused, isFalse);
      expect(resumed.state.currentQuestionIndex, 2);
      expect(resumed.state.answers[1], {_correct(1)});
      expect(resumed.state.answers[2], {_wrong(2)});
      expect(resumed.state.rightAnswers, 1);
      expect(resumed.state.wrongAnswers, 1);
      expect(resumed.state.markedQuestions, {1});
      expect(resumed.state.startedAt, snapshot.startedAt);
      expect(
        resumed.state.timeLeft,
        kExamDuration - const Duration(seconds: 42),
      );
      // Порядок вариантов — как его уже видел пользователь.
      expect(
        resumed.data.questions.map(
          (q) => q.choices.map((c) => c.text).toList(),
        ),
        [
          for (final q in _data().questions)
            [for (final i in snapshot.choiceOrder[q.id]!) q.choices[i].text],
        ],
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        resumed.state.timeLeft,
        kExamDuration - const Duration(seconds: 45),
      );

      // Открытие без «продолжить» (перезагрузка вкладки) — на паузе.
      await tester.runAsync(resumed.close);
      final reopened = _bloc(reloaded, snapshot: snapshot)..add(Init());
      await _pump(tester);
      expect(reopened.state.paused, isTrue);
      expect(reopened.state.currentQuestionIndex, 2);
      await tester.runAsync(reopened.close);
    });

    testWidgets('бездействие дольше порога ставит на паузу; действие '
        'сбрасывает отсчёт', (tester) async {
      final bloc = _bloc(snapshots, idleTimeout: const Duration(minutes: 3))
        ..add(Init());
      await _pump(tester);
      await tester.pump(const Duration(minutes: 2));
      expect(bloc.state.paused, isFalse);
      // Переход по вопросам — активность: отсчёт начинается заново.
      bloc.add(NextQuestion());
      await tester.pump(const Duration(minutes: 2));
      expect(bloc.state.paused, isFalse);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await _pump(tester);
      expect(bloc.state.paused, isTrue);
      await tester.runAsync(bloc.close);
    });

    testWidgets('уход приложения в фон ставит на паузу', (tester) async {
      final bloc = _bloc(snapshots, watchLifecycle: true)..add(Init());
      await _pump(tester);
      expect(bloc.state.paused, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _pump(tester);
      expect(bloc.state.paused, isTrue);
      // Возврат сам по себе не снимает паузу — только кнопка. (Слушатель
      // требует легальной цепочки переходов: paused → hidden → inactive →
      // resumed.)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pump(tester);
      expect(bloc.state.paused, isTrue);
      await tester.runAsync(bloc.close);
    });

    testWidgets('завершение экзамена стирает снимок', (tester) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      expect(snapshots.current, isNotNull);
      bloc.add(FinalizeTest());
      await _pump(tester);
      expect(bloc.state.finalizeTest, isTrue);
      expect(snapshots.current, isNull);
      // Блок не закрываем: обработчик завершения ждёт записи в базу, и
      // close() под FakeAsync его не дождётся; таймер он уже остановил.
    });
  });

  group('экран паузы', () {
    testWidgets('тап по таймеру — экран паузы; «возобновить» возвращает '
        'вопрос', (tester) async {
      await tester.pumpWidget(_app(snapshots));
      await _pump(tester);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      await tester.tap(find.text('45:00'));
      await _pump(tester);
      expect(find.byType(PauseScreen), findsOneWidget);
      expect(find.text('Пауза'), findsOneWidget);
      expect(find.text('Питање број 1'), findsNothing);

      await tester.tap(find.text('Возобновить'));
      await _pump(tester);
      expect(find.byType(PauseScreen), findsNothing);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);
    });

    testWidgets('«завершить» предупреждает, стирает снимок и уводит на '
        'страницу запуска', (tester) async {
      await tester.pumpWidget(_app(snapshots));
      await _pump(tester);
      await tester.tap(find.text('45:00'));
      await _pump(tester);

      await tester.tap(find.text('Завершить').first);
      await _settle(tester);
      expect(find.text('Завершить симуляцию?'), findsOneWidget);
      // «Отмена» оставляет всё как есть.
      await tester.tap(find.text('Отмена'));
      await _settle(tester);
      expect(find.byType(PauseScreen), findsOneWidget);
      expect(snapshots.current, isNotNull);

      await tester.tap(find.text('Завершить').first);
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Завершить'));
      await _settle(tester);
      expect(find.text('страница запуска'), findsOneWidget);
      expect(snapshots.current, isNull);
      // Баннера нет — симуляция брошена.
      expect(find.text('Симуляция экзамена на паузе'), findsNothing);
    });

    testWidgets('«на главную» оставляет симуляцию на паузе: баннер с датой и '
        '«продолжить», который возобновляет с того же места', (tester) async {
      await tester.pumpWidget(_app(snapshots));
      await _pump(tester);
      // Отвечаем и уходим на второй вопрос, чтобы было что восстанавливать.
      await tester.tap(find.text('Тачан одговор 1'));
      await _pump(tester);
      await tester.tap(find.text('Следеће питање'));
      await _pump(tester);
      expect(find.text('Питање: 2 / 3'), findsOneWidget);

      await tester.tap(find.text('45:00'));
      await _pump(tester);
      await tester.tap(find.text('На главную'));
      await _settle(tester);
      expect(find.text('главная'), findsOneWidget);
      expect(find.text('Симуляция экзамена на паузе'), findsOneWidget);
      expect(find.textContaining('Начата '), findsOneWidget);
      expect(find.text('Вопрос 2 из 3, осталось 45:00'), findsOneWidget);

      await tester.tap(find.text('Продолжить'));
      await _settle(tester);
      // Сразу вопрос, без экрана паузы, с тем же номером и ответом.
      expect(find.byType(PauseScreen), findsNothing);
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
      // Без «кнопок как на экзамене» назад ведёт стрелка в нижней панели;
      // листалка доезжает до страницы анимацией.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_outlined));
      await _settle(tester);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);
      final radio = tester.widget<RadioListTile<Choice>>(
        find.widgetWithText(RadioListTile<Choice>, 'Тачан одговор 1'),
      );
      expect(radio.value, _correct(1));
      expect(
        tester
            .widget<RadioGroup<Choice>>(find.byType(RadioGroup<Choice>))
            .groupValue,
        _correct(1),
      );
    });

    testWidgets('снимок с прошлого запуска: симуляция открывается на паузе, '
        'а на странице запуска стоит баннер', (tester) async {
      await snapshots.save(
        PausedSimulation(
          startedAt: DateTime(2026, 9, 22, 21, 5),
          elapsedSeconds: 600,
          savedAt: DateTime(2026, 9, 22, 21, 15),
          questions: const [1, 2, 3],
          currentQuestionIndex: 1,
          choiceOrder: const {
            1: [1, 0],
            2: [0, 1],
            3: [1, 0],
          },
          answers: const {
            1: [0],
          },
          showRightAnswers: true,
        ),
      );
      await tester.pumpWidget(_app(snapshots, initialPath: '/practice'));
      await _settle(tester);
      expect(find.text('Симуляция экзамена на паузе'), findsOneWidget);
      // Дата и время начала — в формате локали.
      expect(
        find.textContaining(RegExp(r'^Начата 22\.09\.2026,? 21:05$')),
        findsOneWidget,
      );
      expect(find.text('Вопрос 2 из 3, осталось 35:00'), findsOneWidget);

      await tester.tap(find.text('Продолжить'));
      await _settle(tester);
      expect(find.byType(PauseScreen), findsNothing);
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
      expect(find.text('35:00'), findsOneWidget);
    });
  });
}
