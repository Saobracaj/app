import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/keyboard_hints.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/presentation/quest_bottom_bar.dart';
import 'package:saobracaj/test/quest/presentation/question_pagination.dart';
import 'package:saobracaj/test/quest/presentation/question_progress_strip.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран вопроса в вебе (задача 1203867458889989): просторное окно браузера
/// получает вебовскую обстановку — раскрытую пагинацию внизу и подсказку
/// клавиш, — а узкое окно (телефонный браузер) собирается ровно как мобильная
/// версия: полоса прогресса под шапкой, внизу одна панель действий, без
/// пагинации и клавиатурных подсказок.

class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
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

Widget _quest() {
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('sr'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AllQuestionsBloc>(
          create: (_) => _StubAllQuestionsBloc(_data()),
        ),
        BlocProvider(
          create: (_) => FeatureFlagsBloc(
            FeatureFlagsRepository(
              GraphqlClient(TokenStorage()),
              TokenStorage(),
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
          home: Quest(
            options: StartTestState(random: false, randomOptionsOrder: false),
            questions: const [1, 2, 3],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    Quest.debugForceWeb = true;
    KeyboardHints.debugForceVisible = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_web').path,
        );
  });

  tearDown(() {
    Quest.debugForceWeb = false;
    KeyboardHints.debugForceVisible = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  testWidgets('просторный веб: пагинация с подсказкой внизу, полосы '
      'прогресса нет', (tester) async {
    // Ширина 800 — больше телефонной (600), но ещё без двухколоночного тела.
    await tester.pumpWidget(_quest());
    await tester.pumpAndSettle();

    expect(find.byType(QuestionPagination), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(KeyboardHints),
        matching: find.text('Прикажи одговор'),
      ),
      findsOneWidget,
    );
    expect(find.byType(QuestionProgressHeader), findsNothing);
    expect(find.byType(QuestBottomBar), findsOneWidget);
  });

  testWidgets('узкий веб собирается как мобильная версия: полоса прогресса '
      'и одна панель действий', (tester) async {
    // Уже 600 (телефон), но с запасом под тестовый шрифт Ahem: его квадратные
    // глифы шире настоящих, и на честных 390 заголовок шапки переполняется
    // только в тестах.
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_quest());
    await tester.pumpAndSettle();

    expect(find.byType(QuestionProgressHeader), findsOneWidget);
    expect(find.byType(QuestBottomBar), findsOneWidget);
    expect(find.byType(QuestionPagination), findsNothing);
    // Клавиатурной подсказки нет — в телефонном браузере нет клавиатуры.
    expect(
      find.descendant(
        of: find.byType(KeyboardHints),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });
}
