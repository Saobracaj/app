import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/statistics/statistics_page.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Симуляция, открытая до того, как банк вопросов загрузился из ассетов
/// (задача 1203867458889984): раньше `Practice` разыменовывал `questionsData!`
/// в первом же кадре и весь экран превращался в серый прямоугольник ошибки —
/// «нажимаю на кнопку — вижу пустой экран». Теперь экран ждёт банк со
/// спиннером и стартует, как только он появился.

/// Банк вопросов, который «загружается» по команде теста, а не сам.
class _ManualAllQuestionsBloc extends AllQuestionsBloc {
  final events = <AllQuestionsBlocEvent>[];

  @override
  void add(AllQuestionsBlocEvent event) => events.add(event);

  void load(QuestionsData data) =>
      emit(AllQuestionsBlocState(questionsData: data));
}

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

Widget _app(_ManualAllQuestionsBloc bank, Widget home) => EasyLocalization(
  useOnlyLangCode: true,
  ignorePluralRules: false,
  supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
  fallbackLocale: const Locale('ru'),
  startLocale: const Locale('sr'),
  path: 'assets/translations',
  assetLoader: const CodegenLoader(),
  child: MultiBlocProvider(
    providers: [
      BlocProvider<AllQuestionsBloc>.value(value: bank),
      BlocProvider(
        create: (_) => FeatureFlagsBloc(
          FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
        ),
      ),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
        home: home,
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    // Ответы пишутся в Drift, а Drift спрашивает у path_provider каталог —
    // подсовываем временный вместо нереализованного плагина.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_exam').path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  testWidgets(
    'симуляция, открытая до загрузки банка: спиннер без ошибки, потом старт',
    (tester) async {
      final bank = _ManualAllQuestionsBloc();
      addTearDown(bank.close);
      await tester.pumpWidget(
        _app(bank, Practice(params: const PracticeParams())),
      );
      await tester.pump();

      // Банка ещё нет — экран ждёт, а не падает.
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Питање:'), findsNothing);

      // Банк загрузился — симуляция стартует сама, без повторного нажатия.
      bank.load(_data());
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);
      expect(find.text('Питање број 1'), findsOneWidget);
    },
  );

  testWidgets('ошибка загрузки банка показывается текстом, а не серым экраном', (
    tester,
  ) async {
    final bank = _ManualAllQuestionsBloc();
    addTearDown(bank.close);
    await tester.pumpWidget(
      _app(bank, Practice(params: const PracticeParams())),
    );
    bank.emit(const AllQuestionsBlocState(errorMessage: 'Нет файла'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Нет файла'), findsOneWidget);

    // Из сбоя должен быть выход без перезапуска приложения.
    bank.events.clear();
    await tester.tap(find.widgetWithText(FilledButton, 'Покушај поново'));
    expect(bank.events.whereType<Load>(), isNotEmpty);
  });

  testWidgets('история ошибок до загрузки банка тоже ждёт, а не падает', (
    tester,
  ) async {
    final bank = _ManualAllQuestionsBloc();
    addTearDown(bank.close);
    await tester.pumpWidget(_app(bank, const StatisticsPage()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
