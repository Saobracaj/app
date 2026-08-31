import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_markdown.dart';
import 'package:saobracaj/test/animations/road_sign.dart';
import 'package:saobracaj/zakon/domain/road_sign_index.dart';
import 'package:saobracaj/zakon/presentation/road_sign_viewer.dart';
import 'package:saobracaj/zakon/zakon.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository() : super(GraphqlClient(TokenStorage()), TokenStorage());

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: const {},
    grants: const {},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

/// Нажатие на дорожный знак (маркер конспекта или знак в правилнике)
/// открывает просмотр: крупный знак с hero-полётом, описание из правилника и
/// ссылка на его абзац.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
    // Прогреваем источник данных: внутри widget-теста ассет из rootBundle
    // не дочитывается (фейковый event loop), и список остаётся пустым.
    await pravilnikDataSource.paragraphs;
  });

  // Статический Future индекса должен рождаться в зоне текущего теста:
  // Future из фейковой зоны предыдущего теста не дождаться.
  setUp(RoadSignIndex.reset);

  Widget wrap(Widget child) {
    final flags = FeatureFlagsBloc(_StubFeatureFlagsRepository());
    return EasyLocalization(
      useOnlyLangCode: true,
      ignorePluralRules: false,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: const Locale('ru'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        // Провайдер над MaterialApp, как в main.dart: просмотрщик пушится на
        // корневой навигатор и должен видеть FeatureFlagsBloc из маршрута.
        builder: (context) => BlocProvider.value(
          value: flags,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  testWidgets('знак конспекта открывает просмотр с описанием и ссылкой', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![II-2](anim/sign-ii-2)')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();

    // Код знака — в заголовке и подписью под изображением; описание по
    // умолчанию сербское, как в законе.
    expect(find.text('II-2'), findsNWidgets(2));
    expect(
      find.textContaining('обавезно заустављање', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Открыть в правилнике'), findsOneWidget);
  });

  testWidgets('знак образца 2017 показывает описание из документа', (
    tester,
  ) async {
    // Зелёная «близина школе» — знак 2017 года; документ теперь тоже 2017-го,
    // и знак стоит в нём под своим номером III-11.
    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![знак](anim/sign-iii-11-2017)')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();

    expect(find.text('III-11-2017'), findsOneWidget);
    expect(
      find.textContaining('близина школе', findRichText: true),
      findsWidgets,
    );
    // Номер документа достоверен (по нему знак ищется в правилнике) —
    // поэтому он на экране.
    expect(find.text('III-11'), findsOneWidget);
    expect(find.text('Открыть в правилнике'), findsOneWidget);
  });

  testWidgets('знака нет в правилнике — крупный знак без описания и ссылки', (
    tester,
  ) async {
    // Файл 2010 года (жёлтый путоказ), чей номер в правилнике 2017-го занят
    // другим знаком — «iii-8-2017», подземни пешачки пролаз (см.
    // legacy2010Files): описания нет, подставлять чужое нельзя — но знак всё
    // равно открывается крупно.
    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![знак](anim/sign-iii-8)')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();

    expect(find.text('III-8'), findsOneWidget);
    expect(find.text('Открыть в правилнике'), findsNothing);
  });

  testWidgets('знак в правилнике нажимается, но без ссылки на правилник', (
    tester,
  ) async {
    // Экран правилника сам показывает официальные знаки нажимаемыми — но
    // ссылка «Открыть в правилнике» оттуда не нужна.
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const Zakon()));
    // Zakon сам грузит данные через Bloc — здесь важен только вложенный
    // просмотр, поэтому берём готовый TappableRoadSign из правилника не
    // через прокрутку, а напрямую через просмотрщик.
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Zakon));
    showRoadSignViewer(context, sign: 'i-1', showPravilnikLink: false);
    await tester.pumpAndSettle();

    // Код — в заголовке и подписью под изображением.
    expect(find.text('I-1'), findsNWidgets(2));
    expect(
      find.textContaining('кривина налево', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Открыть в правилнике'), findsNothing);
  });

  testWidgets('код из подписи правилника первичен для номера и описания', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const Zakon()));
    await tester.pumpAndSettle();

    // Код подписи первичен: просмотр из правилника показывает его, а не имя
    // файла. Файл ii-30-40.svg документ подписывает кодом II-30.
    final context = tester.element(find.byType(Zakon));
    showRoadSignViewer(
      context,
      sign: 'ii-30-40',
      documentCode: 'II-30',
      showPravilnikLink: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('II-30'), findsNWidgets(2));
    expect(find.text('II-30-40'), findsNothing);
    expect(
      find.textContaining('ограничење брзине', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('смахивание закрывает просмотр знака', (tester) async {
    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![II-2](anim/sign-ii-2)')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();
    expect(find.byType(RoadSignViewer), findsOneWidget);

    // Как в просмотре фотографий чата: тащим сам знак вниз и отпускаем.
    await tester.drag(
      find.descendant(
        of: find.byType(RoadSignViewer),
        matching: find.byType(Hero),
      ),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RoadSignViewer), findsNothing);
  });

  testWidgets('смахивание работает по всей области просмотра, не только по знаку', (
    tester,
  ) async {
    // Экран, где описание помещается целиком: любой вертикальный жест по
    // области просмотра — смахивание.
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![II-2](anim/sign-ii-2)')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();
    expect(find.byType(RoadSignViewer), findsOneWidget);

    // Тащим вниз за описание (не за знак): списку прокручиваться некуда,
    // движение уходит в overscroll и закрывает просмотр тем же жестом.
    await tester.drag(
      find.descendant(
        of: find.byType(RoadSignViewer),
        matching: find.text('Открыть в правилнике'),
      ),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RoadSignViewer), findsNothing);
  });

  testWidgets('прокрутка длинного описания не закрывает просмотр', (
    tester,
  ) async {
    // Экран нарочно низкий: описание не помещается, и списку есть куда
    // прокручиваться — движение вверх должно прокручивать, а не закрывать.
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![II-2](anim/sign-ii-2)')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();
    expect(find.byType(RoadSignViewer), findsOneWidget);

    final list = find.descendant(
      of: find.byType(RoadSignViewer),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(list).position;
    expect(position.maxScrollExtent, greaterThan(0));

    // Тащим вверх за низ экрана (центр списка — это сам знак со своим
    // жестом) на половину запаса прокрутки: до нижнего края список не
    // доходит, overscroll не начинается — просмотр остаётся открытым.
    await tester.dragFrom(
      tester.getBottomLeft(list) + const Offset(300, -40),
      Offset(0, -position.maxScrollExtent / 2 - 18),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RoadSignViewer), findsOneWidget);
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('ссылка «Открыть в правилнике» закрывает знак и открывает закон', (
    tester,
  ) async {
    // Широкий экран: правилник выезжает панелью и не требует роутера — так
    // проверяется главное, что просмотрщик уходит с дороги (иначе документ
    // открывался бы под ним, а «назад» вело на «страница не найдена»).
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![II-2](anim/sign-ii-2)')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Открыть в правилнике'));
    await tester.pumpAndSettle();

    expect(find.byType(RoadSignViewer), findsNothing);
    expect(find.byType(Zakon), findsOneWidget);
  });

  testWidgets('знак, нарисованный в иллюстрации, тоже открывается по нажатию', (
    tester,
  ) async {
    var tapsPastSign = 0;
    await tester.pumpWidget(
      wrap(
        GestureDetector(
          onTap: () => tapsPastSign++,
          child: RoadSignScope(
            signs: const ['I-1'],
            builder: (context, signs) => TappableSigns(
              signs: signs,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _OneSignPainter(signs),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Мимо знака нажатие проходит насквозь — сцена сохраняет свои жесты.
    await tester.tapAt(tester.getTopLeft(find.byType(TappableSigns)) + const Offset(150, 150));
    await tester.pumpAndSettle();
    expect(tapsPastSign, 1);
    expect(find.byType(RoadSignViewer), findsNothing);

    await tester.tapAt(tester.getTopLeft(find.byType(TappableSigns)) + const Offset(50, 50));
    await tester.pumpAndSettle();
    expect(tapsPastSign, 1);
    // Код — в заголовке и подписью под изображением.
    expect(find.text('I-1'), findsNWidgets(2));
    expect(
      find.textContaining('кривина налево', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('знак из иллюстрации летит в просмотрщик hero-копией', (
    tester,
  ) async {
    final painter = _OneSignPainter.probe();
    await tester.pumpWidget(
      wrap(
        RoadSignScope(
          signs: const ['I-1'],
          builder: (context, signs) => TappableSigns(
            signs: signs,
            child: CustomPaint(
              size: const Size(200, 200),
              painter: painter..signs = signs,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(painter.hiddenInLastFrame, isFalse);
    final origin = tester.getTopLeft(find.byType(TappableSigns));

    await tester.tapAt(origin + const Offset(50, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Пока знак летит, холст его не рисует (статичная сцена перерисована
    // принудительно), а его место занимает Hero-копия ровно в его
    // прямоугольнике — с тем же тегом, что у знака в просмотрщике.
    expect(painter.hiddenInLastFrame, isTrue);
    final viewer = tester.widget<RoadSignViewer>(find.byType(RoadSignViewer));
    expect(viewer.heroTag, isNotNull);
    final copy = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == viewer.heroTag,
      description: 'hero-копия знака над холстом',
    );
    expect(copy, findsNWidgets(2));
    expect(
      tester.getRect(
        find.ancestor(of: copy.first, matching: find.byType(Positioned)),
      ),
      Rect.fromLTWH(origin.dx + 10, origin.dy + 10, 80, 80),
    );
    await tester.pumpAndSettle();

    // После закрытия и обратного перелёта копия снимается, знак снова рисует
    // сам холст.
    Navigator.of(tester.element(find.byType(RoadSignViewer))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(RoadSignViewer), findsNothing);
    expect(find.byType(Hero), findsNothing);
    expect(painter.hiddenInLastFrame, isFalse);
  });
}

/// Сцена с одним знаком в левом верхнем углу — ровно чтобы проверить слой
/// нажатий поверх холста.
class _OneSignPainter extends CustomPainter {
  _OneSignPainter(this.signs);

  /// Painter, переживающий перестройки: [signs] подменяется в builder'е, а
  /// [hiddenInLastFrame] показывает, что видел холст в последнем кадре.
  _OneSignPainter.probe() : signs = null;

  RoadSigns? signs;
  bool hiddenInLastFrame = false;

  @override
  void paint(Canvas canvas, Size size) {
    final signs = this.signs!;
    hiddenInLastFrame = signs.isHidden('I-1');
    signs.paint(canvas, 'I-1', const Rect.fromLTWH(10, 10, 80, 80));
  }

  @override
  bool shouldRepaint(_OneSignPainter oldDelegate) => oldDelegate.signs != signs;
}
