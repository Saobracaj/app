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
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Регрессия к «серому экрану» по диплинку https://saobracaj.gleb.at/question/8084:
/// холодный старт по прямой ссылке строит экран вопроса раньше, чем банк
/// вопросов загрузился из ассетов. Старый код разыменовывал `questionsData!`
/// и ронял первый кадр; несуществующий id ронял `firstWhere`. Теперь — спиннер,
/// а для неизвестного вопроса — «не найдено» с кнопкой на главную.
///
/// Bloc с управляемым состоянием: настоящий грузит ассеты и статистику из БД,
/// чего в виджет-тесте нет — события гасим, состояние отдаём своё.
class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData? _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

Question _question() => Question(
  id: 8084,
  imageId: 8084,
  text: 'Како треба да поступи возач?',
  choicesReq: 1,
  hasImage: false,
  points: 2,
  choices: [
    const Choice(text: 'Одговор број 0', isCorrect: true),
    const Choice(text: 'Одговор број 1', isCorrect: false),
  ],
  categoryId: 'c',
  subcategoryId: 1,
);

/// Экран вопроса так, как его строит роут `/question/:id` — поверх приложения,
/// у которого банк вопросов ещё в состоянии [data].
Widget _app({required QuestionsData? data, required int questionId}) {
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
          create: (_) => _StubAllQuestionsBloc(data),
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
            questions: [questionId],
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

  testWidgets('пока банк вопросов не загружен, диплинк показывает спиннер', (
    tester,
  ) async {
    await tester.pumpWidget(_app(data: null, questionId: 8084));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('диплинк на несуществующий вопрос — «не найдено», а не крэш', (
    tester,
  ) async {
    final data = QuestionsData(
      categories: const [],
      questions: [_question()],
      practice: const [],
    );
    await tester.pumpWidget(_app(data: data, questionId: 999999));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Питање није пронађено'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('диплинк на существующий вопрос открывает сам вопрос', (
    tester,
  ) async {
    final data = QuestionsData(
      categories: const [],
      questions: [_question()],
      practice: const [],
    );
    await tester.pumpWidget(_app(data: data, questionId: 8084));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Како треба да поступи возач?'), findsOneWidget);
  });
}
