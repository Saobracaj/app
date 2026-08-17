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
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Подсказка по клавиатуре (задача 1217517553850745): рядом со строкой
/// навигации на вебе стоят рисованные клавиши ← / → / пробел с подписями —
/// в тренажёре ([Quest]) и в обоих раскладах симуляции экзамена ([Practice]).
/// Вне веба подсказки нет вовсе.

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

Widget _app(Widget home) {
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
          home: home,
        ),
      ),
    ),
  );
}

Widget _quest(List<int> questions) => _app(
  Quest(
    options: StartTestState(random: false, randomOptionsOrder: false),
    questions: questions,
  ),
);

Widget _practice({
  bool showRightAnswers = true,
  bool buttonsLikeInExam = false,
}) => _app(
  Practice(
    params: PracticeParams(
      showRightAnswers: showRightAnswers,
      buttonsLikeInExam: buttonsLikeInExam,
    ),
  ),
);

/// Симуляция экзамена тикает секундным таймером, так что `pumpAndSettle` тут
/// не сходится: ждём явными кадрами, пока Init блока разложит вопросы.
Future<void> _pumpPractice(WidgetTester tester, Widget practice) async {
  await tester.pumpWidget(practice);
  await tester.pump();
  await tester.pump();
}

/// Подписи подсказки на сербском (стартовая локаль тестов).
const _prev = 'Претходно питање';
const _next = 'Следеће';
const _space = 'Прикажи одговор';

Finder _hintLabel(String text) =>
    find.descendant(of: find.byType(KeyboardHints), matching: find.text(text));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    KeyboardHints.debugForceVisible = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_hints').path,
        );
  });

  tearDown(() {
    KeyboardHints.debugForceVisible = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('KeyboardHints', () {
    testWidgets('вне веба не рисуется вовсе', (tester) async {
      KeyboardHints.debugForceVisible = false;
      await tester.pumpWidget(_app(const Scaffold(body: KeyboardHints())));
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardHints), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('три клавиши с подписями: ←, → и широкий пробел', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const Scaffold(body: KeyboardHints())));
      await tester.pumpAndSettle();
      expect(_hintLabel(_prev), findsOneWidget);
      expect(_hintLabel(_next), findsOneWidget);
      expect(_hintLabel(_space), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.space_bar), findsOneWidget);

      // Колпачок пробела шире колпачков стрелок — как на клавиатуре.
      Size cap(IconData icon) => tester.getSize(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(Container)),
      );
      expect(
        cap(Icons.space_bar).width,
        greaterThan(cap(Icons.arrow_back).width),
      );
      expect(cap(Icons.space_bar).height, cap(Icons.arrow_back).height);
      // Подсказка мелкая: колпачки ниже 20 логических пикселей.
      expect(cap(Icons.arrow_back).height, lessThan(20));
    });

    testWidgets('флаги прячут стрелки и пробел по отдельности', (tester) async {
      await tester.pumpWidget(
        _app(const Scaffold(body: KeyboardHints(showAnswer: false))),
      );
      await tester.pumpAndSettle();
      expect(_hintLabel(_prev), findsOneWidget);
      expect(_hintLabel(_next), findsOneWidget);
      expect(_hintLabel(_space), findsNothing);

      await tester.pumpWidget(
        _app(const Scaffold(body: KeyboardHints(navigation: false))),
      );
      await tester.pumpAndSettle();
      expect(_hintLabel(_prev), findsNothing);
      expect(_hintLabel(_next), findsNothing);
      expect(_hintLabel(_space), findsOneWidget);

      // Нечего подсказывать — пусто.
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: KeyboardHints(navigation: false, showAnswer: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('Тренажёр (Quest)', () {
    testWidgets('подсказка стоит в нижней панели под кнопками', (tester) async {
      await tester.pumpWidget(_quest(const [1, 2, 3]));
      await tester.pumpAndSettle();
      expect(_hintLabel(_prev), findsOneWidget);
      expect(_hintLabel(_next), findsOneWidget);
      expect(_hintLabel(_space), findsOneWidget);

      // Ниже кнопки «Следеће» нижней панели, у самого низа экрана.
      final hint = tester.getBottomLeft(_hintLabel(_space));
      final nextButton = tester.getBottomLeft(
        find.widgetWithText(FilledButton, _next),
      );
      expect(hint.dy, greaterThan(nextButton.dy));
      final screen = tester.getSize(find.byType(Scaffold).first);
      expect(hint.dy, lessThanOrEqualTo(screen.height));
    });

    testWidgets('в прогоне из одного вопроса стрелки не подсказываются', (
      tester,
    ) async {
      await tester.pumpWidget(_quest(const [2]));
      await tester.pumpAndSettle();
      expect(_hintLabel(_prev), findsNothing);
      expect(_hintLabel(_next), findsNothing);
      expect(_hintLabel(_space), findsOneWidget);
    });
  });

  group('Симуляция экзамена (Practice)', () {
    testWidgets('обычные кнопки: подсказка между стрелками и отчётом', (
      tester,
    ) async {
      await _pumpPractice(tester, _practice());
      expect(_hintLabel(_prev), findsOneWidget);
      expect(_hintLabel(_next), findsOneWidget);
      expect(_hintLabel(_space), findsOneWidget);

      final arrows = tester.getCenter(
        find.byIcon(Icons.arrow_forward_ios_outlined),
      );
      final report = tester.getCenter(find.byIcon(Icons.format_list_numbered));
      final hint = tester.getCenter(_hintLabel(_prev));
      expect(hint.dx, greaterThan(arrows.dx));
      expect(hint.dx, lessThan(report.dx));
      expect((hint.dy - arrows.dy).abs(), lessThan(24));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('без показа ответов пробел не подсказывается', (tester) async {
      await _pumpPractice(tester, _practice(showRightAnswers: false));
      expect(_hintLabel(_prev), findsOneWidget);
      expect(_hintLabel(_space), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('кнопки как на экзамене (телефон): подсказка под стопкой '
        'кнопок', (tester) async {
      await _pumpPractice(tester, _practice(buttonsLikeInExam: true));
      expect(_hintLabel(_prev), findsOneWidget);
      expect(_hintLabel(_space), findsOneWidget);
      // Ниже последней кнопки стопки («Прикажи одговор»).
      final button = tester.getBottomLeft(
        find.widgetWithText(ElevatedButton, _space).first,
      );
      final hint = tester.getTopLeft(_hintLabel(_space));
      expect(hint.dy, greaterThan(button.dy));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('кнопки как на экзамене (широкий экран): подсказка в '
        'нижней панели', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpPractice(
        tester,
        _practice(buttonsLikeInExam: true, showRightAnswers: false),
      );
      expect(_hintLabel(_prev), findsOneWidget);
      expect(_hintLabel(_next), findsOneWidget);
      expect(_hintLabel(_space), findsNothing);
      // Под кнопками панели, у нижнего края окна.
      final button = tester.getBottomLeft(find.text('Крај испита'));
      final hint = tester.getTopLeft(_hintLabel(_prev));
      expect(hint.dy, greaterThan(button.dy));
      expect(hint.dy, greaterThan(800));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
