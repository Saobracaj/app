import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
        .ancestor(of: find.text(number), matching: find.byType(AnimatedContainer))
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
        .ancestor(of: find.text(number), matching: find.byType(AnimatedContainer))
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
}
