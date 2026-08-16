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
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Раскладка симуляции экзамена с опцией «кнопки как на экзамене» (задача
/// 1217516196575398): на широком экране кнопки стоят в панели у нижнего края
/// окна как в настоящем экзаменационном ПО — навигация слева, «Прикажи
/// одговор» по центру, «Извештај» и «Крај испита» справа; на телефоне они
/// по-прежнему стопкой под вариантами ответа.

class _StubAllQuestionsBloc extends AllQuestionsBloc {
  _StubAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  void add(AllQuestionsBlocEvent event) {}

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

/// Три вопроса с одним верным ответом из двух, без картинок.
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

Widget _practice({bool showRightAnswers = true}) => EasyLocalization(
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
        home: Practice(
          params: PracticeParams(
            showRightAnswers: showRightAnswers,
            buttonsLikeInExam: true,
          ),
        ),
      ),
    ),
  ),
);

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Симуляция тикает секундным таймером, так что `pumpAndSettle` не сходится:
/// ждём явными кадрами, пока Init блока разложит вопросы.
Future<void> _pump(WidgetTester tester, Widget practice) async {
  await tester.pumpWidget(practice);
  await tester.pump();
  await tester.pump();
}

Rect _buttonRect(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(ElevatedButton)),
);

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

  group('широкий экран', () {
    testWidgets('кнопки в панели у низа окна: навигация слева, «Прикажи '
        'одговор» по центру, отчёт и конец справа', (tester) async {
      _setScreenSize(tester, const Size(1400, 900));
      await _pump(tester, _practice());

      final next = _buttonRect(tester, 'Следеће питање');
      final show = _buttonRect(tester, 'Прикажи одговор');
      final report = _buttonRect(tester, 'Извештај');
      final end = _buttonRect(tester, 'Крај испита');
      // На первом вопросе кнопки «назад» нет — как и в настоящем экзамене.
      expect(find.text('Претходно питање'), findsNothing);

      // Все в одной строке у нижнего края окна.
      for (final r in [next, show, report, end]) {
        expect(r.top, next.top);
        expect(r.bottom, closeTo(900 - 20, 1));
      }
      // Слева направо: следующий → показать ответ → отчёт → конец.
      expect(next.right, lessThan(show.left));
      expect(show.right, lessThan(report.left));
      expect(report.right, lessThan(end.left));
      // «Прикажи одговор» стоит ровно по центру окна, «Крај испита» — у
      // правого края.
      expect(show.center.dx, closeTo(700, 1));
      expect(end.right, closeTo(1400 - 24, 1));
      expect(next.left, closeTo(24, 1));
    });

    testWidgets('панель прибита к низу, а не уезжает с прокруткой; кнопки '
        'работают', (tester) async {
      _setScreenSize(tester, const Size(1400, 900));
      await _pump(tester, _practice());
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      // Кнопки — вне прокручиваемой области.
      expect(
        find.ancestor(
          of: find.text('Крај испита'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      // А сам вопрос — внутри неё.
      expect(
        find.ancestor(
          of: find.text('Питање број 1'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Следеће питање'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
      // На втором вопросе появилась «назад» — слева от «вперёд».
      expect(
        _buttonRect(tester, 'Претходно питање').right,
        lessThan(_buttonRect(tester, 'Следеће питање').left),
      );

      await tester.tap(find.text('Претходно питање'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      await tester.tap(find.text('Крај испита'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('без показа ответов центральной кнопки нет, края на месте', (
      tester,
    ) async {
      _setScreenSize(tester, const Size(1400, 900));
      await _pump(tester, _practice(showRightAnswers: false));

      expect(find.text('Прикажи одговор'), findsNothing);
      expect(_buttonRect(tester, 'Следеће питање').left, closeTo(24, 1));
      expect(_buttonRect(tester, 'Крај испита').right, closeTo(1400 - 24, 1));
    });

    testWidgets('на средней ширине пять кнопок умещаются без переполнения', (
      tester,
    ) async {
      _setScreenSize(tester, const Size(840, 700));
      await _pump(tester, _practice());
      await tester.tap(find.text('Следеће питање'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Претходно питање'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final end = _buttonRect(tester, 'Крај испита');
      expect(end.right, lessThanOrEqualTo(840 - 24 + 1));
    });
  });

  group('узкий экран', () {
    testWidgets('кнопки по-прежнему стопкой под вариантами ответа', (
      tester,
    ) async {
      // Уже порога двухпанельной раскладки (840). Не 390: тестовый шрифт с
      // квадратными глифами вдвое шире настоящего, и шапка на нём
      // переполняется, чего с Inter на телефоне не происходит.
      _setScreenSize(tester, const Size(600, 844));
      await _pump(tester, _practice());

      final next = _buttonRect(tester, 'Следеће питање');
      final end = _buttonRect(tester, 'Крај испита');
      final report = _buttonRect(tester, 'Извештај');
      final show = _buttonRect(tester, 'Прикажи одговор');
      // Одна колонка, один левый край, порядок как раньше.
      for (final r in [end, report, show]) {
        expect(r.left, next.left);
      }
      expect(next.bottom, lessThanOrEqualTo(end.top));
      expect(end.bottom, lessThanOrEqualTo(report.top));
      expect(report.bottom, lessThanOrEqualTo(show.top));
      // И они внутри прокрутки, а не в отдельной панели.
      expect(
        find.ancestor(
          of: find.text('Крај испита'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });
  });
}
