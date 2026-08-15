import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/keyboard_pagination.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Клавиатурная пагинация (задача 1217511139126286): ← / → листают вопросы,
/// пробел = «Прикажи одговор» — и в тренажёре ([Quest]), и в симуляции
/// экзамена ([Practice]). Плюс сам виджет [KeyboardPagination]: что он
/// перехватывает, а что обязан пропускать.

class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

/// Три вопроса с одним верным ответом (первый вариант) из двух.
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

Widget _quest() => _app(
  Quest(
    options: StartTestState(random: false, randomOptionsOrder: false),
    questions: const [1, 2, 3],
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

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Симуляция экзамена тикает секундным таймером, так что `pumpAndSettle` тут
/// не сходится: ждём явными кадрами, пока Init блока разложит вопросы.
Future<void> _pumpPractice(WidgetTester tester, Widget practice) async {
  await tester.pumpWidget(practice);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    // Запись ответа идёт в Drift, а Drift спрашивает у path_provider, куда
    // класть файл — подсовываем временный каталог вместо нереализованного
    // плагина.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_kbd').path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('KeyboardPagination', () {
    testWidgets('← / → / пробел вызывают колбэки, остальное игнорирует', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardPagination(
            onPrevious: () => log.add('prev'),
            onNext: () => log.add('next'),
            onShowAnswer: () => log.add('space'),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      expect(await simulateKeyDownEvent(LogicalKeyboardKey.arrowRight), isTrue);
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(await simulateKeyDownEvent(LogicalKeyboardKey.arrowLeft), isTrue);
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      expect(await simulateKeyDownEvent(LogicalKeyboardKey.space), isTrue);
      await simulateKeyUpEvent(LogicalKeyboardKey.space);
      // Чужая клавиша — не наша забота.
      expect(await simulateKeyDownEvent(LogicalKeyboardKey.keyA), isFalse);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyA);
      expect(log, ['next', 'prev', 'space']);
    });

    testWidgets('автоповтор зажатой клавиши и модификаторы не срабатывают', (
      tester,
    ) async {
      var next = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardPagination(
            onNext: () => next++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      await simulateKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await simulateKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await simulateKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(next, 1);

      // Ctrl+→ — комбинация браузера/системы, не наша.
      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      expect(
        await simulateKeyDownEvent(LogicalKeyboardKey.arrowRight),
        isFalse,
      );
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(next, 1);
    });

    testWidgets('колбэк null — событие не съедается, а всплывает дальше', (
      tester,
    ) async {
      final bubbled = <LogicalKeyboardKey>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            onKeyEvent: (_, event) {
              bubbled.add(event.logicalKey);
              return KeyEventResult.ignored;
            },
            child: KeyboardPagination(
              onNext: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();
      // → есть кому обработать — до родителя не доходит.
      await simulateKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowRight);
      // ← и пробел без колбэка — уходят выше.
      await simulateKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await simulateKeyDownEvent(LogicalKeyboardKey.space);
      await simulateKeyUpEvent(LogicalKeyboardKey.space);
      expect(
        bubbled.where(
          (k) =>
              k == LogicalKeyboardKey.arrowRight ||
              k == LogicalKeyboardKey.arrowLeft ||
              k == LogicalKeyboardKey.space,
        ),
        // Каждое нажатие всплывает дважды: key down и key up.
        [
          LogicalKeyboardKey.arrowRight, // только key up
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.space,
        ],
      );
    });

    testWidgets('в текстовом поле стрелки и пробел остаются за полем', (
      tester,
    ) async {
      final log = <String>[];
      final controller = TextEditingController(text: 'абв');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyboardPagination(
              onPrevious: () => log.add('prev'),
              onNext: () => log.add('next'),
              onShowAnswer: () => log.add('space'),
              child: Column(
                children: [
                  TextField(controller: controller),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Пока фокус на нашем узле — работаем.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(log, ['next']);

      // Пользователь кликнул в поле: курсор ходит стрелками, пробел —
      // символ. Ничего из этого не перехватываем.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(KeyboardPagination.isEditingText(), isTrue);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.space);
      expect(log, ['next']);
    });
  });

  group('Тренажёр (Quest)', () {
    testWidgets('→ и ← листают вопросы, на краях — ничего', (tester) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();
      expect(find.text('Питање 1 / 3'), findsOneWidget);

      // ← на первом вопросе — некуда.
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Питање 1 / 3'), findsOneWidget);

      // → без выбора — пропуск вопроса, как кнопкой «Следеће».
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('Питање 2 / 3'), findsOneWidget);
      expect(find.text('Питање број 2'), findsOneWidget);

      // Фокус остался у обработчика и после смены вопроса.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('Питање 3 / 3'), findsOneWidget);

      // → на последнем — не завершает прогон и не открывает диалог.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Питање 3 / 3'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Питање 2 / 3'), findsOneWidget);
    });

    testWidgets('пробел = «Прикажи одговор»', (tester) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();

      Finder card(String text) => find.ancestor(
        of: find.text(text),
        matching: find.byType(AnswerOptionCard),
      );
      expect(
        tester.widget<AnswerOptionCard>(card('Тачан одговор 1')).revealed,
        isFalse,
      );

      await _press(tester, LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnswerOptionCard>(card('Тачан одговор 1')).revealed,
        isTrue,
      );
      final reveal = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Прикажи одговор'),
      );
      expect(reveal.onPressed, isNull);

      // Повторный пробел после раскрытия ничего не ломает.
      await _press(tester, LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Питање 1 / 3'), findsOneWidget);
    });

    testWidgets('→ с неверным ответом раскрывает верный и не уходит дальше', (
      tester,
    ) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Нетачан одговор 1'));
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(find.text('Питање 1 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Уже раскрыто — → идёт дальше.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Питање 2 / 3'), findsOneWidget);
    });
  });

  group('Симуляция экзамена (Practice)', () {
    testWidgets('→ и ← листают вопросы, пробел показывает ответ', (
      tester,
    ) async {
      await _pumpPractice(tester, _practice());
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Питање: 2 / 3'), findsOneWidget);

      // Новый вопрос — новый узел фокуса; клавиши работают по-прежнему.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Питање: 3 / 3'), findsOneWidget);

      // → на последнем — некуда (и никакого диалога завершения).
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Питање: 3 / 3'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('Питање: 2 / 3'), findsOneWidget);

      // Пробел = «Прикажи одговор»: кнопка гаснет.
      await _press(tester, LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 300));
      final reveal = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Прикажи одговор'),
      );
      expect(reveal.onPressed, isNull);

      // Снимаем экран, чтобы таймер экзамена остановился до конца теста.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('без показа ответов пробел ничего не делает; → сохраняет '
        'выбор', (tester) async {
      await _pumpPractice(tester, _practice(showRightAnswers: false));

      expect(find.text('Прикажи одговор'), findsNothing);
      await _press(tester, LogicalKeyboardKey.space);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      // Выбор + → : ответ записан, идём дальше; ← возвращает выбранный ответ.
      await tester.tap(find.text('Тачан одговор 1'));
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('Питање: 1 / 3'), findsOneWidget);
      final group = tester.widget<RadioGroup<Choice>>(
        find.byType(RadioGroup<Choice>),
      );
      expect(group.groupValue?.text, 'Тачан одговор 1');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('кнопки как на экзамене: клавиши работают так же', (
      tester,
    ) async {
      await _pumpPractice(tester, _practice(buttonsLikeInExam: true));
      expect(find.text('Питање: 1 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 300));
      // Ответ раскрыт — верный вариант подсвечен зелёным контейнером.
      final tile = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('Тачан одговор 2'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        tile.decoration,
        isNot(equals(const BoxDecoration(color: Colors.transparent))),
      );

      await tester.pumpWidget(const SizedBox());
    });
  });
}
