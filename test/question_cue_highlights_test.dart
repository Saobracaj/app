import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/quest/question_features/data/question_analytics_repository.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_cues_bloc.dart';
import 'package:saobracaj/test/quest/state_management/quest_content_bloc.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Подсветка ключевых фраз на экране вопроса: после «показать ответ» слова
/// из вкладки «Анализ» выделяются в вариантах ответа — но только у тех, кому
/// эта вкладка доступна, и только после раскрытия. (Подсветка в тексте
/// самого вопроса бывает лишь у связок «фраза вопроса → ответ», а в текущей
/// базе таких связок не осталось — см. `question_analytics_test.dart`.)
///
/// Вопрос 8076 — реальный вопрос про алкоголь за рулём: в базе для него есть
/// маркер на весь верный ответ («не сме да има алкохола у крви») и маркер на
/// фразу внутри длинного неверного варианта («садржај алкохола у крви»).
/// Данные — из настоящего `assets/question_analytics.json`.
final _question = Question(
  id: 8076,
  imageId: 0,
  text:
      'Возач са пробном возачком дозволом, када управља возилом у саобраћају '
      'на путу:',
  choicesReq: 1,
  hasImage: false,
  points: 3,
  choices: const [
    Choice(
      text:
          'не сме да има алкохола у крви само у периоду од 23,00 до 05,00 '
          'сати',
      isCorrect: false,
    ),
    Choice(
      text: 'сме да има садржај алкохола у крви највише до 0,30 mg/ml',
      isCorrect: false,
    ),
    Choice(text: 'не сме да има алкохола у крви', isCorrect: true),
  ],
  categoryId: '26',
  subcategoryId: 103,
);

Widget _screen({required bool revealed, required bool analysisEnabled}) {
  return EasyLocalization(
    useOnlyLangCode: true,
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
              create: (_) {
                final bloc = FeatureFlagsBloc(
                  FeatureFlagsRepository(
                    GraphqlClient(TokenStorage()),
                    TokenStorage(),
                  ),
                );
                if (analysisEnabled) {
                  bloc.add(
                    FeatureFlagsSnapshotChanged(
                      FeatureFlagsSnapshot.resolve(
                        localOverrides: const {},
                        grants: {AppFeature.questionAnalysis.key},
                        authenticated: true,
                      ),
                    ),
                  );
                }
                return bloc;
              },
            ),
            BlocProvider(create: (_) => TranslationsBloc()),
            BlocProvider(
              create: (_) => QuestContentBloc(
                {..._question.choices},
                {},
                _question.id,
                revealAnswers: revealed,
              ),
            ),
          ],
          child: Scaffold(
            body: ListView(
              children: [
                QuestionContent(question: _question, showFeatureTabs: false),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Разметка, которую получил каждый Markdown на экране (вопрос + варианты).
List<String> _markdownData(WidgetTester tester) => [
  for (final w in tester.widgetList<Markdown>(find.byType(Markdown))) w.data,
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    getIt.registerLazySingleton<QuestionAnalyticsRepository>(
      QuestionAnalyticsRepository.new,
    );
    getIt.registerFactoryParam<QuestionCuesBloc, int, void>(
      (id, _) => QuestionCuesBloc(getIt(), id),
    );
  });

  tearDown(() => getIt.reset());

  /// Ассет аналитики декодируется в отдельном изоляте — фейковое время его
  /// не продвинет, поэтому ждём по-настоящему.
  Future<void> show(WidgetTester tester, Widget widget) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  testWidgets('после раскрытия ответа фразы подсвечены в вариантах', (
    tester,
  ) async {
    await show(tester, _screen(revealed: true, analysisEnabled: true));

    final data = _markdownData(tester);
    // «Всегда верный» ответ подсвечен целиком…
    expect(data, contains(contains('~~не сме да има алкохола у крви~~')));
    // …а «всегда неверная» фраза — внутри длинного варианта.
    expect(data, contains(contains('~~садржај алкохола у крви~~ највише')));
    // Вариант без подсказок остаётся как был — хотя его текст и начинается
    // с той же фразы, подсказка привязана к своему варианту, а не к словам.
    expect(
      data,
      contains(
        predicate<String>(
          (d) => d.contains('23,00 до 05,00') && !d.contains('~~'),
        ),
      ),
    );
    // Тильды — только разметка: на экране их нет.
    expect(find.textContaining('~~', findRichText: true), findsNothing);
  });

  testWidgets('до раскрытия ответа подсветки нет', (tester) async {
    await show(tester, _screen(revealed: false, analysisEnabled: true));

    expect(_markdownData(tester).any((d) => d.contains('~~')), isFalse);
  });

  testWidgets('без доступа к вкладке «Анализ» подсветки нет', (tester) async {
    await show(tester, _screen(revealed: true, analysisEnabled: false));

    expect(_markdownData(tester).any((d) => d.contains('~~')), isFalse);
  });
}
