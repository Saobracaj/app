import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/question_pager.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:saobracaj/test/quest/presentation/question_progress_strip.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guest_flags_without_discussion.dart';

/// Прокрутка вопросов настоящим [PageView] (задача 1217635084826817): что
/// [QuestionPager] считает свайпом, куда при этом едет прогон в тренажёре и
/// как за пальцем идёт подсветка полосы прогресса.

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

Widget _quest() => EasyLocalization(
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
      BlocProvider<FeatureFlagsBloc>(
        create: (_) => GuestFlagsWithoutDiscussionBloc(),
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
          questions: const [1, 2, 3],
        ),
      ),
    ),
  ),
);

/// Протяжка пальцем шаг за шагом, с настоящими метками времени — так же, как
/// её ведёт живой палец.
///
/// [tester.drag] тут не годится: он выдаёт весь порог одним событием, а
/// листалка выигрывает арену у `SelectionArea` именно тем, что её порог ниже
/// — при движении рывками оба перешагивают свои пороги в одном событии, и
/// побеждает тот, кто ближе к пальцу.
Future<TestGesture> _drag(
  WidgetTester tester,
  Finder target, {
  required double distance,
  double step = 12,
  Duration frame = const Duration(milliseconds: 16),
  Offset drift = Offset.zero,
  PointerDeviceKind kind = PointerDeviceKind.touch,
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
  return gesture;
}

Future<void> _swipe(
  WidgetTester tester,
  Finder target, {
  required double distance,
  double step = 12,
  Duration frame = const Duration(milliseconds: 16),
  Offset drift = Offset.zero,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final gesture = await _drag(
    tester,
    target,
    distance: distance,
    step: step,
    frame: frame,
    drift: drift,
    kind: kind,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Тело страницы, повторяющее устройство экрана вопроса: прокручиваемый
/// список, а в нём текст в `SelectionArea`.
class _PagerHarness extends StatefulWidget {
  const _PagerHarness({required this.log, this.controllers});

  final List<String> log;
  final List<ScrollController>? controllers;

  @override
  State<_PagerHarness> createState() => _PagerHarnessState();
}

class _PagerHarnessState extends State<_PagerHarness> {
  int index = 0;
  final position = ValueNotifier<double>(0);

  @override
  void dispose() {
    position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Кнопка листает программно — так же, как кнопки нижней панели.
            TextButton(
              onPressed: () => setState(() => index++),
              child: const Text('дальше'),
            ),
            Expanded(
              child: QuestionPager(
                index: index,
                itemCount: 3,
                position: position,
                onIndexChanged: (value) {
                  widget.log.add('index:$value');
                  setState(() => index = value);
                },
                onLeaving: (value) => widget.log.add('leave:$value'),
                itemBuilder: (context, i) {
                  final controller = ScrollController();
                  widget.controllers?.add(controller);
                  return ListView(
                    controller: controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SelectionArea(child: Text('Питање број ${i + 1}')),
                      const SizedBox(height: 2000),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
              Directory.systemTemp.createTempSync('saobracaj_pager').path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('QuestionPager', () {
    late List<String> log;

    setUp(() => log = <String>[]);

    testWidgets('свайп по тексту в SelectionArea листает страницу', (
      tester,
    ) async {
      // На Android `SelectionArea` забирает горизонтальную протяжку жадно и
      // при этом ничего с ней не делает — из-за неё свайп по самому тексту
      // вопроса и пропадал.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_PagerHarness(log: log));
      await tester.pump();

      await _swipe(tester, find.text('Питање број 1'), distance: -300);
      // Сбрасываем до `expect`: сработавшая проверка оставила бы подмену
      // платформы следующим тестам.
      debugDefaultTargetPlatformOverride = null;
      expect(log, ['index:1', 'leave:0']);
      expect(find.text('Питање број 2'), findsOneWidget);
    });

    testWidgets('косая протяжка прокручивает тело, а не листает', (
      tester,
    ) async {
      final controllers = <ScrollController>[];
      await tester.pumpWidget(_PagerHarness(log: log, controllers: controllers));
      await tester.pump();

      // Палец идёт вверх с заметным заносом вбок — это всё ещё прокрутка.
      await _swipe(
        tester,
        find.byType(PageView),
        distance: -60,
        step: 4,
        drift: const Offset(0, -20),
      );
      expect(log, isEmpty);
      expect(
        controllers.where((c) => c.hasClients).map((c) => c.offset),
        anyElement(greaterThan(100)),
      );
    });

    testWidgets('мышью не листается — там протяжка выделяет текст', (
      tester,
    ) async {
      await tester.pumpWidget(_PagerHarness(log: log));
      await tester.pump();

      await _swipe(
        tester,
        find.byType(PageView),
        distance: -300,
        kind: PointerDeviceKind.mouse,
      );
      expect(log, isEmpty);
    });

    testWidgets('программный переход не считают за жест', (tester) async {
      await tester.pumpWidget(_PagerHarness(log: log));
      await tester.pump();

      await tester.tap(find.text('дальше'));
      await tester.pumpAndSettle();

      expect(find.text('Питање број 2'), findsOneWidget);
      // Ответ на оставленном вопросе записывает сама кнопка — листалке
      // повторять это нельзя.
      expect(log, isEmpty);
    });

    testWidgets('положение идёт за пальцем, а не прыгает по факту перехода', (
      tester,
    ) async {
      await tester.pumpWidget(_PagerHarness(log: log));
      await tester.pump();
      final state = tester.state<_PagerHarnessState>(
        find.byType(_PagerHarness),
      );
      expect(state.position.value, 0);

      final gesture = await _drag(
        tester,
        find.byType(PageView),
        distance: -tester.getSize(find.byType(PageView)).width / 3,
      );
      expect(state.position.value, greaterThan(0.2));
      expect(state.position.value, lessThan(0.5));

      await gesture.up();
      await tester.pumpAndSettle();
      // Доехали до целой страницы — и это ровно тот вопрос, о котором
      // листалка сообщила наружу.
      expect(state.position.value, state.index.toDouble());
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

    testWidgets('свайп вперёд записывает выбор; неверный ответ раскрыт на '
        'оставленном вопросе', (tester) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Нетачан одговор 1'));
      await tester.pump();
      // Страницу за пальцем не остановить, поэтому прогон уходит дальше —
      // а верные ответы раскрываются на том вопросе, с которого ушли.
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      expect(find.text('Питање 2 / 3'), findsOneWidget);

      await _swipe(tester, find.text('Питање број 2'), distance: 240);
      expect(find.text('Питање 1 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('вопрос ждёт таким, каким его оставили', (tester) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Тачан одговор 1'));
      await tester.pump();
      await _swipe(tester, find.text('Питање број 1'), distance: -240);
      await _swipe(tester, find.text('Питање број 2'), distance: 240);

      expect(find.text('Питање 1 / 3'), findsOneWidget);
      // Выбор на месте — прежде он сбрасывался при каждом возврате.
      final selected = tester.widget<AnswerOptionCard>(
        find.ancestor(
          of: find.text('Тачан одговор 1'),
          matching: find.byType(AnswerOptionCard),
        ),
      );
      final other = tester.widget<AnswerOptionCard>(
        find.ancestor(
          of: find.text('Нетачан одговор 1'),
          matching: find.byType(AnswerOptionCard),
        ),
      );
      expect(selected.selected, isTrue);
      expect(other.selected, isFalse);
    });

    testWidgets('полоса прогресса переезжает за пальцем', (tester) async {
      await tester.pumpWidget(_quest());
      await tester.pumpAndSettle();

      Color colorOf(int index) => tester
          .widgetList<QuestionProgressSegment>(
            find.byType(QuestionProgressSegment),
          )
          .elementAt(index)
          .color;

      final primary = colorOf(0);
      final plain = colorOf(1);
      expect(primary, isNot(plain));

      // На полпути между вопросами подсвечены оба соседа — и ни один из них
      // не в полную силу.
      final gesture = await _drag(
        tester,
        find.text('Питање број 1'),
        distance: -tester.getSize(find.byType(PageView)).width / 2,
      );
      expect(colorOf(0), isNot(primary));
      expect(colorOf(0), isNot(plain));
      expect(colorOf(1), isNot(plain));
      expect(colorOf(1), isNot(primary));

      await gesture.up();
      await tester.pumpAndSettle();
      // Доехали: подсветка целиком на втором вопросе.
      expect(colorOf(0), plain);
      expect(colorOf(1), primary);
    });
  });
}
