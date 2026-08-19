import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/swipe_pagination.dart';
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

/// Свайпы по вопросам (задача 1217568064138016): протяжка влево — следующий
/// вопрос, вправо — предыдущий, и в тренажёре ([Quest]), и в симуляции
/// экзамена ([Practice]). Плюс сам [SwipePagination]: что он считает свайпом,
/// а что обязан оставить прокрутке, выделению текста и мыши.

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
/// [SwipePagination] выигрывает арену у `SelectionArea` именно тем, что его
/// порог ниже — при движении рывками оба перешагивают свои пороги в одном
/// событии, и побеждает тот, кто ближе к пальцу.
///
/// [distance] — путь по горизонтали (влево — отрицательный), [step] — сколько
/// пикселей палец проходит за кадр, [frame] — длительность кадра. Вместе они
/// задают и скорость броска.
Future<void> _swipe(
  WidgetTester tester,
  Finder target, {
  required double distance,
  double step = 12,
  Duration frame = const Duration(milliseconds: 16),
  Offset drift = Offset.zero,
  PointerDeviceKind kind = PointerDeviceKind.touch,
  bool settle = true,
}) async {
  var elapsed = Duration.zero;
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: kind,
  );
  final steps = (distance.abs() / step).ceil();
  final dx = distance / steps;
  for (var i = 0; i < steps; i++) {
    elapsed += frame;
    await gesture.moveBy(Offset(dx, 0) + drift, timeStamp: elapsed);
    await tester.pump(frame);
  }
  await gesture.up();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Тело, повторяющее устройство экрана вопроса: прокручиваемый список, а в
/// нём текст в `SelectionArea`.
Widget _body(ScrollController controller) => ListView(
  controller: controller,
  children: const [
    SelectionArea(child: Text('Питање број 1')),
    SizedBox(height: 2000),
  ],
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

  group('SwipePagination', () {
    late List<String> log;
    late ScrollController controller;

    Widget harness({bool first = false, bool last = false}) => MaterialApp(
      home: Scaffold(
        body: SwipePagination(
          onPrevious: first ? null : () => log.add('prev'),
          onNext: last ? null : () => log.add('next'),
          child: _body(controller),
        ),
      ),
    );

    setUp(() {
      log = <String>[];
      controller = ScrollController();
    });

    tearDown(() => controller.dispose());

    testWidgets('влево — следующий вопрос, вправо — предыдущий', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      await _swipe(tester, find.byType(ListView), distance: -240);
      expect(log, ['next']);

      await _swipe(tester, find.byType(ListView), distance: 240);
      expect(log, ['next', 'prev']);
      // Содержимое вернулось на место — сдвиг это только анимация.
      expect(controller.offset, 0);
    });

    testWidgets('свайп по тексту в SelectionArea тоже листает', (tester) async {
      // На Android `SelectionArea` забирает горизонтальную протяжку жадно и
      // при этом ничего с ней не делает — из-за неё свайп по самому тексту
      // вопроса и пропадал.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(harness());
      await tester.pump();

      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      // Сбрасываем до `expect`: сработавшая проверка оставила бы подмену
      // платформы следующим тестам (`addTearDown` для неё уже поздно —
      // фреймворк сверяет debug-переменные раньше).
      debugDefaultTargetPlatformOverride = null;
      expect(log, ['next']);
    });

    testWidgets('короткая медленная протяжка не листает', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      await _swipe(
        tester,
        find.byType(ListView),
        distance: -40,
        step: 4,
        frame: const Duration(milliseconds: 32),
      );
      expect(log, isEmpty);
    });

    testWidgets('быстрый бросок листает и с короткого пути', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      // 48 px за три кадра — путь до порога не дотягивает, скорость дотягивает.
      await _swipe(tester, find.byType(ListView), distance: -48, step: 16);
      expect(log, ['next']);
    });

    testWidgets('мышью не листается — там протяжка выделяет текст', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      await _swipe(
        tester,
        find.byType(ListView),
        distance: -240,
        kind: PointerDeviceKind.mouse,
      );
      expect(log, isEmpty);
    });

    testWidgets('вертикальная протяжка прокручивает список, а не листает', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      // Палец идёт вверх с заметным заносом вбок — это всё ещё прокрутка.
      await _swipe(
        tester,
        find.byType(ListView),
        distance: -60,
        step: 4,
        drift: const Offset(0, -20),
      );
      expect(log, isEmpty);
      expect(controller.offset, greaterThan(100));
    });

    testWidgets('у края прогона свайп ничего не вызывает', (tester) async {
      await tester.pumpWidget(harness(first: true, last: true));
      await tester.pump();

      await _swipe(tester, find.byType(ListView), distance: -240);
      await _swipe(tester, find.byType(ListView), distance: 240);
      expect(log, isEmpty);
      // Обе стороны закрыты — жест вообще не ставится, и прокрутка тела
      // остаётся ровно такой, какой была бы без обёртки.
      await _swipe(
        tester,
        find.byType(ListView),
        distance: -60,
        step: 4,
        drift: const Offset(0, -20),
      );
      expect(controller.offset, greaterThan(100));
    });

    testWidgets('листать назад некуда — свайп вправо молчит, вперёд работает', (
      tester,
    ) async {
      await tester.pumpWidget(harness(first: true));
      await tester.pump();

      await _swipe(tester, find.byType(ListView), distance: 240);
      expect(log, isEmpty);

      await _swipe(tester, find.byType(ListView), distance: -240);
      expect(log, ['next']);
    });
  });

  group('Тренажёр (Quest)', () {
    testWidgets('свайпы листают вопросы, на краях — ничего', (tester) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();
      expect(find.text('Питање 1 / 3'), findsOneWidget);

      // Вправо на первом вопросе — некуда.
      await _swipe(tester, find.text('Питање број 1'), distance: 240);
      expect(find.text('Питање 1 / 3'), findsOneWidget);

      // Влево без выбора — пропуск вопроса, как кнопкой «Следеће».
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(find.text('Питање 2 / 3'), findsOneWidget);
      expect(find.text('Питање број 2'), findsOneWidget);

      await _swipe(tester, find.text('Питање број 2'), distance: -240);
      expect(find.text('Питање 3 / 3'), findsOneWidget);

      // Влево на последнем — не завершает прогон и не открывает диалог.
      await _swipe(tester, find.text('Питање број 3'), distance: -240);
      expect(find.text('Питање 3 / 3'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await _swipe(tester, find.text('Питање број 3'), distance: 240);
      expect(find.text('Питање 2 / 3'), findsOneWidget);
    });

    testWidgets('свайп вперёд с неверным ответом раскрывает верный и остаётся '
        'на вопросе', (tester) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Нетачан одговор 1'));
      await tester.pump();
      await _swipe(tester, find.text('Питање број 1'), distance: -240);

      expect(find.text('Питање 1 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Уже раскрыто — следующий свайп идёт дальше.
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(find.text('Питање 2 / 3'), findsOneWidget);
    });
  });

  group('Симуляция экзамена (Practice)', () {
    testWidgets('свайпы листают вопросы', (tester) async {
      await _pumpPractice(tester, _practice());
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      await _swipe(
        tester,
        find.text('Питање број 1'),
        distance: 240,
        settle: false,
      );
      expect(find.text('Питање: 1 / 3'), findsOneWidget);

      await _swipe(
        tester,
        find.text('Питање број 1'),
        distance: -240,
        settle: false,
      );
      expect(find.text('Питање: 2 / 3'), findsOneWidget);

      await _swipe(
        tester,
        find.text('Питање број 2'),
        distance: 240,
        settle: false,
      );
      expect(find.text('Питање: 1 / 3'), findsOneWidget);
    });
  });
}
