import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:saobracaj/test/quest/presentation/quest_app_bar.dart';
import 'package:saobracaj/test/quest/presentation/quest_bottom_bar.dart';
import 'package:saobracaj/test/quest/presentation/question_progress_strip.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/quest/state_management/quest_bloc.dart';
import 'package:saobracaj/test/quest/state_management/quest_content_bloc.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Смоук-тест переработанного экрана вопроса: собирает тот же Scaffold, что и
/// `Quest` для одного вопроса (без AllQuestionsBloc и загрузки ассетов), с
/// настоящими сербскими переводами через [CodegenLoader] — чтобы проверить и
/// плюральные формы.
Question _question({int correct = 2, int options = 4}) => Question(
  id: 1,
  imageId: 1,
  text: 'Како треба да поступи возач?',
  choicesReq: correct,
  hasImage: false,
  points: 2,
  choices: [
    for (var i = 0; i < options; i++)
      Choice(text: 'Одговор број $i', isCorrect: i < correct),
  ],
  categoryId: 'c',
  subcategoryId: 1,
);

Widget _screen(Question question, {ValueChanged<int>? onQuestionSelected}) {
  final entries = [
    QuestionNavigatorEntry(
      questionId: question.id,
      number: 1,
      points: question.points,
      status: QuestionStatus.unanswered,
    ),
    const QuestionNavigatorEntry(
      questionId: 2,
      number: 2,
      points: 3,
      status: QuestionStatus.unanswered,
    ),
  ];
  final data = QuestionsData(
    categories: [],
    questions: [question],
    practice: [],
  );
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('sr'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => FeatureFlagsBloc(
                FeatureFlagsRepository(
                  GraphqlClient(TokenStorage()),
                  TokenStorage(),
                ),
              ),
            ),
            BlocProvider(
              create: (_) => QuestBloc(data, [question.id, 2], null),
            ),
            BlocProvider(create: (_) => TranslationsBloc()),
            BlocProvider(
              create: (_) =>
                  QuestContentBloc({...question.choices}, {}, question.id),
            ),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              appBar: QuestAppBar(
                questionNumber: 1,
                questionCount: 2,
                points: question.points,
                questionId: question.id,
              ),
              body: QuestionProgressHeader(
                entries: entries,
                currentQuestionId: question.id,
                onQuestionSelected: onQuestionSelected ?? (_) {},
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [QuestionContent(question: question)],
                ),
              ),
              bottomNavigationBar: QuestBottomBar(
                question: question,
                first: true,
                last: false,
              ),
            ),
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

  testWidgets('экран вопроса: шапка, полоса, чип, карточки, нижняя панель', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_question()));
    await tester.pumpAndSettle();

    // Шапка: локализованный заголовок с номером и баллами (плюрал).
    expect(find.text('Питање 1 / 2'), findsOneWidget);
    expect(find.text('2 поена'), findsOneWidget);

    // Чип «Потребна 2 одговора» — сербская плюральная форма few.
    expect(find.text('Потребна 2 одговора'), findsOneWidget);

    // Четыре карточки вариантов и закреплённые действия.
    expect(find.byType(AnswerOptionCard), findsNWidgets(4));
    expect(find.text('Прикажи одговор'), findsOneWidget);
    expect(find.text('Следеће'), findsOneWidget);
  });

  testWidgets('подсветка после раскрытия: ✓ у верных, ✕ только у выбранного '
      'неверного', (tester) async {
    await tester.pumpWidget(_screen(_question()));
    await tester.pumpAndSettle();

    // Выбираем один верный (0) и один неверный (3) вариант.
    await tester.tap(find.text('Одговор број 0'));
    await tester.pump();
    await tester.tap(find.text('Одговор број 3'));
    await tester.pump();

    await tester.tap(find.text('Прикажи одговор'));
    await tester.pumpAndSettle();

    // Оба верных варианта помечены ✓; ✕ — только у выбранного неверного,
    // невыбранный неверный (2) остаётся нейтральным.
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.byIcon(Icons.close), findsOneWidget);

    // После раскрытия «Прикажи одговор» гаснет.
    final reveal = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Прикажи одговор'),
    );
    expect(reveal.onPressed, isNull);
  });

  testWidgets('полоса прогресса раскрывается в чипы, чип выбирает вопрос '
      'и схлопывает полосу', (tester) async {
    int? picked;
    await tester.pumpWidget(
      _screen(_question(), onQuestionSelected: (id) => picked = id),
    );
    await tester.pumpAndSettle();

    Finder segmentOf(String number) => find
        .ancestor(
          of: find.text(number),
          matching: find.byType(AnimatedContainer),
        )
        .first;

    // Свёрнуто: сегмент — тонкая полоска.
    expect(tester.getSize(segmentOf('2')).height, 6);

    // Первый тап раскрывает полосу в чипы, ничего не выбирая.
    await tester.tap(segmentOf('2'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(tester.getSize(segmentOf('2')).height, 32);

    // Тап по чипу другого вопроса выбирает его и схлопывает полосу обратно.
    await tester.tap(segmentOf('2'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, 2);
    expect(tester.getSize(segmentOf('2')).height, 6);
  });

  testWidgets('потяг тела вниз у самого верха раскрывает полосу, прокрутка '
      'вверх — сворачивает', (tester) async {
    await tester.pumpWidget(_screen(_question()));
    await tester.pumpAndSettle();

    Finder segmentOf(String number) => find
        .ancestor(
          of: find.text(number),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    // Внешний ListView тела: вложенные списки (разметка вопроса) не скроллятся.
    final body = find.byType(ListView).first;

    // Изначально свёрнута.
    expect(tester.getSize(segmentOf('2')).height, 6);

    // Тянем содержимое вниз, находясь на самом верху, — полоса раскрывается
    // сама, без тапа.
    await tester.drag(body, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(tester.getSize(segmentOf('2')).height, 32);

    // Прокрутка вверх сворачивает её обратно.
    await tester.drag(body, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getSize(segmentOf('2')).height, 6);
  });

  testWidgets('145 вопросов: раскрытая полоса не съедает весь экран, '
      'чипы скроллятся', (tester) async {
    // Экзаменационная категория со 145 вопросами: раньше раскрытый навигатор
    // занимал экран целиком, не скроллился, и закрыть его можно было только
    // выбрав вопрос (скриншот в задаче 1217292094173343).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionProgressHeader(
            entries: [
              for (var i = 1; i <= 145; i++)
                QuestionNavigatorEntry(
                  questionId: i,
                  number: i,
                  points: 2,
                  status: QuestionStatus.unanswered,
                ),
            ],
            currentQuestionId: 1,
            onQuestionSelected: (_) {},
            child: ListView(
              children: const [SizedBox(key: Key('body'), height: 2000)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Раскрываем тапом по полосе.
    await tester.tap(find.text('1'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Тело вопроса осталось на экране — навигатор ограничен по высоте.
    expect(find.byKey(const Key('body')), findsOneWidget);

    // Дальние чипы достижимы прокруткой внутри навигатора.
    final strip = find.byType(SingleChildScrollView);
    await tester.dragUntilVisible(
      find.text('145'),
      strip,
      const Offset(0, -120),
    );
    expect(find.text('145'), findsOneWidget);
  });

  testWidgets('нельзя выбрать больше нужного: лишний тап не выбирается, '
      'даёт вибрацию и подсказку', (tester) async {
    // Ловим обращения к платформе, чтобы проверить вибрацию.
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    // Вопрос с двумя верными вариантами из четырёх.
    await tester.pumpWidget(_screen(_question()));
    await tester.pumpAndSettle();

    bool selected(String text) => tester
        .widget<AnswerOptionCard>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(AnswerOptionCard),
          ),
        )
        .selected;

    await tester.tap(find.text('Одговор број 0'));
    await tester.pump();
    await tester.tap(find.text('Одговор број 1'));
    await tester.pump();
    expect(selected('Одговор број 0'), isTrue);
    expect(selected('Одговор број 1'), isTrue);

    // Третий тап — лимит исчерпан: вариант не выбирается, выбранные не
    // сбрасываются.
    await tester.tap(find.text('Одговор број 2'));
    await tester.pump();
    expect(selected('Одговор број 2'), isFalse);
    expect(selected('Одговор број 0'), isTrue);
    expect(selected('Одговор број 1'), isTrue);

    // Вибрация и подсказка с сербской плюральной формой few.
    expect(platformCalls, contains('HapticFeedback.vibrate'));
    await tester.pump();
    expect(
      find.text('Можете изабрати само 2 одговора. Поништите сувишни избор.'),
      findsOneWidget,
    );

    // Снятие выбора освобождает место — теперь третий вариант выбирается.
    await tester.tap(find.text('Одговор број 0'));
    await tester.pump();
    await tester.tap(find.text('Одговор број 2'));
    await tester.pump();
    expect(selected('Одговор број 2'), isTrue);
    expect(selected('Одговор број 0'), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('текст вопроса и вариантов выделяется и копируется, тап по '
      'варианту по-прежнему выбирает его', (tester) async {
    // Перехватываем буфер обмена, чтобы прочитать скопированный текст.
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_screen(_question()));
    await tester.pumpAndSettle();

    // Вопрос и варианты живут в одной SelectionArea — выделение может
    // тянуться от текста вопроса до текста ответа.
    final region = find.byType(SelectableRegion);
    expect(region, findsOneWidget);
    expect(
      find.descendant(
        of: region,
        matching: find.text('Како треба да поступи возач?'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: region, matching: find.text('Одговор број 3')),
      findsOneWidget,
    );

    // Долгий тап (touch) выделяет слово в тексте вопроса; «Копировать» кладёт
    // его в буфер обмена.
    await tester.longPress(find.text('Како треба да поступи возач?'));
    await tester.pumpAndSettle();
    // Копируем через CopySelectionTextIntent — тот же обработчик, что и у
    // пункта «Копировать» контекстного меню (copySelection депрекейтнут).
    // Контекст должен быть потомком SelectableRegion, иначе интент не найдёт
    // Actions региона.
    Actions.invoke(
      tester.element(find.text('Како треба да поступи возач?')),
      CopySelectionTextIntent.copy,
    );
    await tester.pump();
    expect(clipboard, isNotNull);
    expect(clipboard, isNotEmpty);
    expect('Како треба да поступи возач?', contains(clipboard!.trim()));

    // Протяжка мышью от вопроса до ответа: в буфере и вопрос, и вариант.
    clipboard = null;
    final from = tester.getTopLeft(find.text('Како треба да поступи возач?'));
    final to = tester.getBottomRight(find.text('Одговор број 1'));
    final gesture = await tester.startGesture(
      from + const Offset(1, 1),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(to - const Offset(1, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    Actions.invoke(
      tester.element(find.text('Како треба да поступи возач?')),
      CopySelectionTextIntent.copy,
    );
    await tester.pump();
    expect(clipboard, contains('Како треба да поступи возач?'));
    expect(clipboard, contains('Одговор број 1'));

    // Обычный тап по варианту не перехвачен выделением: карточка выбирается.
    await tester.tap(find.text('Одговор број 2'));
    await tester.pump();
    final card = tester.widget<AnswerOptionCard>(
      find.ancestor(
        of: find.text('Одговор број 2'),
        matching: find.byType(AnswerOptionCard),
      ),
    );
    expect(card.selected, isTrue);
    await tester.pumpAndSettle();
  });
}
