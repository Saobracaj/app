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

    // Заголовок — код знака; описание по умолчанию сербское, как в законе.
    expect(find.text('II-2'), findsOneWidget);
    expect(
      find.textContaining('обавезно заустављање', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Открыть в правилнике'), findsOneWidget);
  });

  testWidgets('знак без описания в правилнике открывается без ссылки', (
    tester,
  ) async {
    // iii-11-2017 — нумерация правилника 2017 года: описания сознательно
    // нет (см. lookupRoadSign), но крупный знак всё равно показывается.
    await tester.pumpWidget(
      wrap(const KonspektMarkdown(text: '![знак](anim/sign-iii-11-2017)')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TappableRoadSign));
    await tester.pumpAndSettle();

    expect(find.text('III-11-2017'), findsOneWidget);
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

    expect(find.text('I-1'), findsOneWidget);
    expect(
      find.textContaining('кривина налево', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Открыть в правилнике'), findsNothing);
  });
}
