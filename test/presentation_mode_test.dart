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
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/domain/quiz_option.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:saobracaj/test/quest/presentation/quest_bottom_bar.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/quest/state_management/quest_bloc.dart';
import 'package:saobracaj/test/quest/state_management/quest_content_bloc.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/test/start_test.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «Режим презентации» (задача 1217517553850753): ответы раскрыты сразу,
/// кнопки «показать ответ» нет, вместо «завершить» — «закрыть», в статистику
/// ничего не пишется.
Question _question({int id = 1, int correct = 2, int options = 4}) => Question(
  id: id,
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

/// Тот же каркас экрана, что в quest_screen_test, но блоки прогона созданы в
/// режиме презентации; [last] — стоим ли на последнем вопросе.
Widget _screen(Question question, {required bool last}) {
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
              create: (_) =>
                  QuestBloc(data, [question.id, 2], null, presentation: true),
            ),
            BlocProvider(create: (_) => TranslationsBloc()),
            BlocProvider(
              create: (_) => QuestContentBloc(
                {...question.choices},
                {},
                question.id,
                presentation: true,
              ),
            ),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: ListView(children: [QuestionContent(question: question)]),
              bottomNavigationBar: QuestBottomBar(
                question: question,
                first: true,
                last: last,
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

  testWidgets('презентация: ответы раскрыты сразу, кнопки «показать ответ» '
      'нет, варианты не выбираются', (tester) async {
    await tester.pumpWidget(_screen(_question(), last: false));
    await tester.pumpAndSettle();

    // Оба верных варианта уже помечены ✓ — как после «показать ответ».
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.byType(AnswerOptionCard), findsNWidgets(4));

    // Самой кнопки «показать ответ» нет; «Следеће» — есть.
    expect(find.text('Прикажи одговор'), findsNothing);
    expect(find.text('Следеће'), findsOneWidget);

    // Тап по варианту ничего не выбирает — карточки раскрыты и не реагируют.
    await tester.tap(find.text('Одговор број 3'));
    await tester.pump();
    final content = tester.element(find.byType(QuestionContent));
    expect(content.read<QuestContentBloc>().state.selectedChoices, isEmpty);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('презентация: на последнем вопросе вместо «завершить» — '
      '«закрыть»', (tester) async {
    await tester.pumpWidget(_screen(_question(), last: true));
    await tester.pumpAndSettle();

    expect(find.text('Затвори'), findsOneWidget);
    expect(find.text('Заврши тест'), findsNothing);
    expect(find.text('Прикажи одговор'), findsNothing);
  });

  // У каждого вопроса теперь свой блок (их держит экран прогона), так что
  // «смена вопроса» — это новый блок, а не сброс старого.
  test('QuestContentBloc в презентации открывает вопрос уже раскрытым', () async {
    final q1 = _question(id: 1);
    final q2 = _question(id: 2);
    final first = QuestContentBloc({...q1.choices}, {}, q1.id, presentation: true);
    final second = QuestContentBloc({...q2.choices}, {}, q2.id, presentation: true);

    expect(first.state.showCorrectAnswers, isTrue);
    expect(second.state.showCorrectAnswers, isTrue);
    expect(second.state.selectedChoices, isEmpty);

    await first.close();
    await second.close();
  });

  test('QuestContentBloc без презентации открывает вопрос нераскрытым', () async {
    final q1 = _question(id: 1);
    final q2 = _question(id: 2);
    final first = QuestContentBloc({...q1.choices}, {}, q1.id);
    expect(first.state.showCorrectAnswers, isFalse);
    first.add(ShowCorrectAnswers());
    await Future<void>.delayed(Duration.zero);
    expect(first.state.showCorrectAnswers, isTrue);

    // Соседний вопрос от этого раскрытым не становится.
    final second = QuestContentBloc({...q2.choices}, {}, q2.id);
    expect(second.state.showCorrectAnswers, isFalse);

    await first.close();
    await second.close();
  });

  test('адрес прогона несёт presentation=true только когда режим включён', () {
    const off = StartTestState(random: false, randomOptionsOrder: false);
    const on = StartTestState(
      random: false,
      randomOptionsOrder: false,
      presentation: true,
    );
    expect(
      quizRunPath(questionIds: [1, 2], options: off),
      isNot(contains('presentation')),
    );
    expect(
      quizRunPath(questionIds: [1, 2], options: on),
      '/quest?q=1,2&randomOptionsOrder=false&random=false&presentation=true',
    );
  });

  test('переключатель презентации запоминается между прогонами', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = QuizPreferencesRepository();
    await prefs.bootstrap();

    final bloc = StartTestBloc(prefs);
    expect(bloc.state.presentation, isFalse);
    bloc.add(TogglePresentation());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.presentation, isTrue);
    expect(prefs.isEnabled(QuizOption.presentationMode), isTrue);
    await bloc.close();

    // Новый блок стартует с сохранённого значения.
    final again = StartTestBloc(prefs);
    expect(again.state.presentation, isTrue);
    await again.close();
  });
}
