import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:saobracaj/test/quest/presentation/question_image_card.dart';
import 'package:saobracaj/test/quest/preview/question_preview_sheet.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bloc с готовыми вопросами: настоящий грузит ассеты и статистику из БД,
/// чего в виджет-тесте нет — события гасим, состояние отдаём своё.
class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state => AllQuestionsBlocState(questionsData: _data);
}

Question _question({int correct = 2, int options = 4, bool hasImage = false}) =>
    Question(
      id: 7921,
      imageId: 10003,
      text: 'Како треба да поступи возач?',
      choicesReq: correct,
      hasImage: hasImage,
      points: 2,
      choices: [
        for (var i = 0; i < options; i++)
          Choice(text: 'Одговор број $i', isCorrect: i < correct),
      ],
      categoryId: 'c',
      subcategoryId: 1,
    );

/// Экран, с которого открывают предпросмотр: кнопка «open» пушит шит.
Widget _host(Question question) {
  final data = QuestionsData(
    categories: [
      const Category(id: 'c', name: 'Основе безбедности', subcategories: []),
    ],
    questions: [question],
    practice: const [],
  );
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('sr'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    // Провайдер выше MaterialApp — как в приложении: шит живёт в навигаторе,
    // а не внутри экрана, который его открыл.
    child: BlocProvider<AllQuestionsBloc>(
      create: (_) => _StubAllQuestionsBloc(data),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showQuestionPreview(context, question.id),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPreview(WidgetTester tester, Question question) async {
  await tester.pumpWidget(_host(question));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('предпросмотр показывает заголовок, текст и варианты ответа', (
    tester,
  ) async {
    await _openPreview(tester, _question());

    // Заголовок — название категории и баллы (сербская плюральная форма).
    expect(find.text('Основе безбедности'), findsOneWidget);
    expect(find.text('2 поена'), findsOneWidget);
    expect(find.text('Како треба да поступи возач?'), findsOneWidget);
    expect(find.byType(AnswerOptionCard), findsNWidgets(4));

    // Никаких вкладок и дополнительной обвязки: только «Затвори» и «Прошири»,
    // «Одговори» появляется лишь после выбора варианта.
    expect(find.text('Затвори'), findsOneWidget);
    expect(find.text('Прошири'), findsOneWidget);
    expect(find.text('Одговори'), findsNothing);

    // Экран под шитом остаётся на месте — это шит, а не переход.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('кнопка «Одговори» появляется после выбора и раскрывает ответы', (
    tester,
  ) async {
    await _openPreview(tester, _question());

    await tester.tap(find.text('Одговор број 0'));
    await tester.pumpAndSettle();
    expect(find.text('Одговори'), findsOneWidget);

    // Выбран один из двух верных — ответ не принимается.
    await tester.tap(find.text('Одговори'));
    await tester.pumpAndSettle();
    expect(find.text('Нисте означили потребан број одговора'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    await tester.tap(find.text('Одговор број 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Одговори'));
    await tester.pumpAndSettle();

    // Оба верных помечены ✓, кнопка ответа уходит.
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.text('Одговори'), findsNothing);
  });

  testWidgets('«Затвори» закрывает шит и возвращает на исходный экран', (
    tester,
  ) async {
    await _openPreview(tester, _question());

    await tester.tap(find.text('Затвори'));
    await tester.pumpAndSettle();

    expect(find.byType(AnswerOptionCard), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('фотография вопроса — hero, общий с полным экраном', (
    tester,
  ) async {
    await _openPreview(tester, _question(hasImage: true));

    final hero = tester.widget<Hero>(
      find.descendant(
        of: find.byType(QuestionImageCard),
        matching: find.byType(Hero),
      ),
    );
    expect(hero.tag, questionImageHeroTag(10003));
  });

  testWidgets('несуществующий вопрос: сообщение вместо пустого шита', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_question()));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('open'));
    showQuestionPreview(context, 999999);
    await tester.pumpAndSettle();

    expect(find.text('Питање није пронађено'), findsOneWidget);
  });
}
