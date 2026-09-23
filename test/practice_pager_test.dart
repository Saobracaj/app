import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/practice/data/paused_simulation_repository.dart';
import 'package:saobracaj/test/practice/practice.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Симуляция экзамена листается настоящим [PageView] ([QuestionPager], как и
/// тренажёр — см. `question_pager_test.dart`): протяжка влево — следующий
/// вопрос, вправо — предыдущий, страница едет за пальцем. Здесь — что при этом
/// происходит с ответами: свайп записывает выбор так же, как «следеће питање»,
/// неверный ответ раскрывается на оставленной странице, а вопрос, к которому
/// вернулись, застают таким, каким оставили.

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

Widget _practice() => _app(
  Practice(
    params: PracticeParams(showRightAnswers: true, buttonsLikeInExam: false),
  ),
);

/// Симуляция экзамена тикает секундным таймером, так что `pumpAndSettle` тут
/// не сходится: ждём явными кадрами, пока Init блока разложит вопросы.
Future<void> _pumpPractice(WidgetTester tester, Widget practice) async {
  await tester.pumpWidget(practice);
  await tester.pump();
  await tester.pump();
}

/// Протяжка пальцем шаг за шагом, с настоящими метками времени — так же, как
/// её ведёт живой палец.
///
/// [tester.drag] тут не годится: он выдаёт весь порог одним событием, а
/// листалка выигрывает арену у `SelectionArea` именно тем, что её порог ниже
/// — при движении рывками оба перешагивают свои пороги в одном событии, и
/// побеждает тот, кто ближе к пальцу.
///
/// [distance] — путь по горизонтали (влево — отрицательный). После отпускания
/// страница доезжает до места явными кадрами: `pumpAndSettle` с секундным
/// таймером симуляции не сходится.
Future<TestGesture> _drag(
  WidgetTester tester,
  Finder target, {
  required double distance,
  double step = 12,
  Duration frame = const Duration(milliseconds: 16),
}) async {
  var elapsed = Duration.zero;
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.touch,
  );
  final steps = (distance.abs() / step).ceil();
  final dx = distance / steps;
  for (var i = 0; i < steps; i++) {
    elapsed += frame;
    await gesture.moveBy(Offset(dx, 0), timeStamp: elapsed);
    await tester.pump(frame);
  }
  return gesture;
}

Future<void> _swipe(
  WidgetTester tester,
  Finder target, {
  required double distance,
}) async {
  final gesture = await _drag(tester, target, distance: distance);
  await gesture.up();
  await _settle(tester);
}

/// Пружина листалки доезжает до страницы за секунду с небольшим.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Блок прогона — по нему проверяем, что записано.
PracticeBloc _practiceBloc(WidgetTester tester) =>
    BlocProvider.of<PracticeBloc>(tester.element(find.byType(Scaffold).first));

/// Цвет подложки варианта: прозрачный, пока верные ответы не раскрыты.
Color? _optionColor(WidgetTester tester, String text) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(of: find.text(text), matching: find.byType(AnimatedContainer))
        .first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    // Симуляция пишет снимок хода в репозиторий из getIt.
    getIt.registerLazySingleton<PausedSimulationRepository>(
      PausedSimulationRepository.new,
    );
  });

  tearDown(() => getIt.reset());

  setUp(() {
    // Запись ответа идёт в Drift, а Drift спрашивает у path_provider, куда
    // класть файл — подсовываем временный каталог вместо нереализованного
    // плагина.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              Directory.systemTemp.createTempSync('saobracaj_swipe').path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('Симуляция экзамена (Practice)', () {
    testWidgets('свайпы листают вопросы, на краях — ничего', (tester) async {
      await _pumpPractice(tester, _practice());
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      // Вправо на первом вопросе — некуда.
      await _swipe(tester, find.text('Питање број 1'), distance: 240);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
      expect(find.text('Питање број 2'), findsOneWidget);
      // Доехав, листалка держит на экране один вопрос.
      expect(find.text('Питање број 1'), findsNothing);

      await _swipe(tester, find.text('Питање број 2'), distance: -240);
      expect(find.text('Питање: 3 / 3'), findsOneWidget);

      // Влево на последнем — не завершает экзамен и не открывает диалог.
      await _swipe(tester, find.text('Питање број 3'), distance: -240);
      expect(find.text('Питање: 3 / 3'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await _swipe(tester, find.text('Питање број 3'), distance: 240);
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
    });

    testWidgets('сосед виден уже под пальцем', (tester) async {
      await _pumpPractice(tester, _practice());
      final gesture = await _drag(
        tester,
        find.text('Питање број 1'),
        distance: -192,
      );
      // Палец ещё не отпущен — а следующий вопрос уже въезжает справа.
      expect(find.text('Питање број 1'), findsOneWidget);
      expect(find.text('Питање број 2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Питање број 2')).dx,
        greaterThan(tester.getTopLeft(find.text('Питање број 1')).dx),
      );
      await gesture.up();
      await _settle(tester);
    });

    testWidgets('свайп вперёд записывает выбор; неверный ответ раскрыт на '
        'оставленном вопросе', (tester) async {
      await _pumpPractice(tester, _practice());
      await tester.tap(find.text('Нетачан одговор 1'));
      await tester.pump();

      // Страницу за пальцем не остановить, поэтому прогон уходит дальше —
      // а верные ответы раскрываются на том вопросе, с которого ушли.
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(find.text('Питање: 2 / 3'), findsOneWidget);
      expect(_practiceBloc(tester).state.answers, {
        1: {const Choice(text: 'Нетачан одговор 1', isCorrect: false)},
      });

      await _swipe(tester, find.text('Питање број 2'), distance: 240);
      expect(find.text('Питање: 1 / 3'), findsOneWidget);
      expect(
        _optionColor(tester, 'Тачан одговор 1'),
        isNot(Colors.transparent),
      );
      expect(
        _optionColor(tester, 'Нетачан одговор 1'),
        isNot(Colors.transparent),
      );
      // Пока раскрытое не увидели, свайп дальше ничего не записывает заново:
      // тот же выбор второй раз в историю не идёт.
      final recorded = _practiceBloc(tester).state.answers;
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(_practiceBloc(tester).state.answers, recorded);
    });

    testWidgets('верный ответ записывается без раскрытия', (tester) async {
      await _pumpPractice(tester, _practice());
      await tester.tap(find.text('Тачан одговор 1'));
      await tester.pump();

      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(_practiceBloc(tester).state.answers, {
        1: {const Choice(text: 'Тачан одговор 1', isCorrect: true)},
      });
      await _swipe(tester, find.text('Питање број 2'), distance: 240);
      expect(_optionColor(tester, 'Тачан одговор 1'), Colors.transparent);
    });

    testWidgets('вопрос ждёт таким, каким его оставили', (tester) async {
      await _pumpPractice(tester, _practice());
      await tester.tap(find.text('Тачан одговор 1'));
      await tester.pump();
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      await _swipe(tester, find.text('Питање број 2'), distance: 240);

      expect(find.text('Питање: 1 / 3'), findsOneWidget);
      expect(
        tester
            .widget<RadioGroup<Choice>>(find.byType(RadioGroup<Choice>))
            .groupValue,
        const Choice(text: 'Тачан одговор 1', isCorrect: true),
      );
    });

    testWidgets('стрелка «→» после свайпа едет с той страницы, где стоим', (
      tester,
    ) async {
      await _pumpPractice(tester, _practice());
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(find.text('Питање: 2 / 3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_forward_ios_outlined));
      await _settle(tester);
      expect(find.text('Питање: 3 / 3'), findsOneWidget);
      expect(find.text('Питање број 3'), findsOneWidget);
      expect(find.text('Питање број 2'), findsNothing);
    });
  });
}
