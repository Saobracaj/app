import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/practice/data/paused_simulation_repository.dart';
import 'package:saobracaj/test/practice/finalize_practice.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Проходной порог для статистики (OWNCUP-83): результат симуляции попадает
/// в `practice_records` (историю попыток, статистику, синхронизацию) только
/// если отвечено не меньше [kMinAnsweredForStatistics] вопросов. Открытая и
/// брошенная симуляция результат показывает, но в статистику не пишется.

/// Вопросов в банке — с запасом над порогом, чтобы было чем переступить его.
final _bankSize = kMinAnsweredForStatistics + 3;

class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

/// Банк из [_bankSize] вопросов с одним верным ответом из двух; один вариант
/// экзамена — весь банк по порядку.
QuestionsData _data() => QuestionsData(
  categories: const [],
  questions: [
    for (var id = 1; id <= _bankSize; id++)
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
  practice: [
    [for (var id = 1; id <= _bankSize; id++) id],
  ],
);

Choice _correct(int id) => Choice(text: 'Тачан одговор $id', isCorrect: true);

PracticeBloc _bloc(PausedSimulationRepository snapshots) => PracticeBloc(
  _data(),
  const PracticeParams(showRightAnswers: true),
  snapshots: snapshots,
  idleTimeout: null,
  watchLifecycle: false,
);

/// Отвечает верно на первые [count] вопросов варианта.
void _answer(PracticeBloc bloc, int count) {
  for (var id = 1; id <= count; id++) {
    bloc.add(AddAnswer(id, {_correct(id)}));
  }
}

/// Симуляция тикает секундным таймером, так что `pumpAndSettle` не сходится:
/// ждём явными кадрами. Запись в базу — реальный async: её дожидаемся через
/// `runAsync`.
Future<void> _pump(WidgetTester tester, [int frames = 3]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}

Future<void> _finalize(WidgetTester tester, PracticeBloc bloc) async {
  bloc.add(FinalizeTest());
  await _pump(tester);
  // Запись попытки (или её отсутствие) — после реального await'а базы.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.runAsync(() => repository.getPracticeRecords());
  await _pump(tester);
}

Widget _resultScreen(PracticeBloc bloc) => EasyLocalization(
  useOnlyLangCode: true,
  supportedLocales: const [Locale('ru')],
  fallbackLocale: const Locale('ru'),
  startLocale: const Locale('ru'),
  path: 'assets/translations',
  assetLoader: const CodegenLoader(),
  child: MultiBlocProvider(
    providers: [
      BlocProvider<AllQuestionsBloc>(
        create: (_) => _StubAllQuestionsBloc(_data()),
      ),
      BlocProvider(
        create: (_) => FeatureFlagsBloc(
          FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
        ),
      ),
      BlocProvider<PracticeBloc>.value(value: bloc),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
        home: const FinalizePracticeWidget(),
      ),
    ),
  ),
);

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
    // Ответы и попытки пишутся в Drift, а Drift спрашивает у path_provider
    // каталог — подсовываем временный вместо нереализованного плагина.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_threshold').path,
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

  group('порог для статистики', () {
    testWidgets('порог — осмысленная доля варианта из 41 вопроса', (
      tester,
    ) async {
      expect(kMinAnsweredForStatistics, inInclusiveRange(5, 21));
    });

    testWidgets('меньше порога ответов: результат есть, записи в истории '
        'попыток нет', (tester) async {
      final before = await tester.runAsync(
        () => repository.getPracticeRecords(),
      );
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      _answer(bloc, kMinAnsweredForStatistics - 1);
      await _pump(tester);
      await _finalize(tester, bloc);

      expect(bloc.state.finalizeTest, isTrue);
      expect(bloc.state.answeredCount, kMinAnsweredForStatistics - 1);
      expect(bloc.state.countedInStatistics, isFalse);
      expect(bloc.state.attemptSaved, isFalse);
      // Результат при этом посчитан как обычно: неотвеченные — ошибки.
      expect(bloc.state.finalPoints, 2 * (kMinAnsweredForStatistics - 1));
      expect(
        bloc.state.finalWrongQuestions.length,
        _bankSize - (kMinAnsweredForStatistics - 1),
      );
      // Экзамен окончен — снимок стёрт, продолжать нечего.
      expect(snapshots.current, isNull);

      final after = await tester.runAsync(
        () => repository.getPracticeRecords(),
      );
      expect(after!.length, before!.length);
      await tester.runAsync(bloc.close);
    });

    testWidgets('ровно порог ответов: попытка записана', (tester) async {
      final before = await tester.runAsync(
        () => repository.getPracticeRecords(),
      );
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      _answer(bloc, kMinAnsweredForStatistics);
      await _pump(tester);
      await _finalize(tester, bloc);

      expect(bloc.state.countedInStatistics, isTrue);
      expect(bloc.state.answeredCount, kMinAnsweredForStatistics);
      expect(bloc.state.attemptSaved, isTrue);

      final after = await tester.runAsync(
        () => repository.getPracticeRecords(),
      );
      expect(after!.length, before!.length + 1);
      final record = after.first;
      expect(record.uuid, bloc.state.attemptUuid);
      expect(record.points, 2 * kMinAnsweredForStatistics);
      expect(record.mistakes, _bankSize - kMinAnsweredForStatistics);
      await tester.runAsync(bloc.close);
    });

    testWidgets('пустой выбор ответом не считается', (tester) async {
      final before = await tester.runAsync(
        () => repository.getPracticeRecords(),
      );
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      _answer(bloc, kMinAnsweredForStatistics - 1);
      bloc.add(AddAnswer(kMinAnsweredForStatistics, const {}));
      await _pump(tester);
      await _finalize(tester, bloc);

      expect(bloc.state.answeredCount, kMinAnsweredForStatistics - 1);
      expect(bloc.state.countedInStatistics, isFalse);
      final after = await tester.runAsync(
        () => repository.getPracticeRecords(),
      );
      expect(after!.length, before!.length);
      await tester.runAsync(bloc.close);
    });
  });

  group('экран результата', () {
    testWidgets('неучтённый результат помечен, чат о попытке скрыт', (
      tester,
    ) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      _answer(bloc, 1);
      await _pump(tester);
      await _finalize(tester, bloc);

      await tester.pumpWidget(_resultScreen(bloc));
      await _pump(tester);
      expect(find.byKey(const Key('simulation_not_counted')), findsOneWidget);
      expect(
        find.textContaining('не учтён в статистике'),
        findsOneWidget,
      );
      expect(
        find.textContaining('$kMinAnsweredForStatistics'),
        findsOneWidget,
      );
      await tester.runAsync(bloc.close);
    });

    testWidgets('учтённый результат без пометки', (tester) async {
      final bloc = _bloc(snapshots)..add(Init());
      await _pump(tester);
      _answer(bloc, kMinAnsweredForStatistics);
      await _pump(tester);
      await _finalize(tester, bloc);

      await tester.pumpWidget(_resultScreen(bloc));
      await _pump(tester);
      expect(find.byKey(const Key('simulation_not_counted')), findsNothing);
      await tester.runAsync(bloc.close);
    });
  });
}
