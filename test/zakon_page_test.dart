import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/zakon/zakon.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Флаги фич не ходят в сеть: закону нужен только `russian_content` (кнопка
/// «РУ» в шапке), поэтому снимок собирается из фиксированного набора грантов.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository()
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: const {'russian_content': false},
    grants: const {},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

/// Проверяется раскладка страницы закона, а не его текст: `assets/parsed_zakon.json`
/// весит 2,5 МБ, и `rootBundle.loadString` на нём в тестовой среде не
/// возвращается (большие строки декодируются в отдельном изоляте), поэтому
/// список приезжает пустым. Разбор оглавления покрыт отдельно —
/// `zakon_contents_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

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
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: BlocProvider.value(value: flags, child: child),
        ),
      ),
    );
  }

  /// Задаёт размер окна на время теста — от него зависит вся раскладка закона.
  void setWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  testWidgets('на широком экране оглавление стоит сбоку, а не под кнопкой', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    await tester.pumpWidget(wrap(const Zakon()));
    await tester.pumpAndSettle();

    expect(find.text('СОДЕРЖАНИЕ'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  // Закон, открытый выдвижной панелью поверх вопроса (`openZakon` на широком
  // экране), сам узкая колонка — оглавление сбоку в неё не влезет.
  testWidgets('в выдвижной панели оглавление остаётся за кнопкой', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    await tester.pumpWidget(wrap(const Zakon(asPanel: true)));
    await tester.pumpAndSettle();

    expect(find.text('СОДЕРЖАНИЕ'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('на узком экране оглавление по-прежнему за кнопкой', (
    tester,
  ) async {
    setWindow(tester, const Size(400, 800));
    await tester.pumpWidget(wrap(const Zakon()));
    await tester.pumpAndSettle();

    expect(find.text('СОДЕРЖАНИЕ'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  // Полоса прокрутки должна идти по правому краю окна, а колесо мыши работать
  // в любой его точке: сам список занимает всю ширину, читаемой колонку делают
  // поля, а не сужение скроллируемого.
  testWidgets(
    'список закона занимает всю ширину области, читаемость — полями',
    (tester) async {
      setWindow(tester, const Size(1400, 900));
      await tester.pumpWidget(wrap(const Zakon()));
      await tester.pumpAndSettle();

      final listFinder = find.byType(ScrollablePositionedList);
      expect(listFinder, findsOneWidget);
      // 1400 минус колонка оглавления (300) и разделитель (1).
      expect(tester.getSize(listFinder).width, 1099);

      final padding = tester
          .widget<ScrollablePositionedList>(listFinder)
          .padding;
      expect(padding, isNotNull);
      expect(padding!.left, greaterThan(100));
      expect(padding.left, padding.right);
    },
  );

  testWidgets('в узком окне поля не съедают текст', (tester) async {
    setWindow(tester, const Size(400, 800));
    await tester.pumpWidget(wrap(const Zakon()));
    await tester.pumpAndSettle();

    final listFinder = find.byType(ScrollablePositionedList);
    expect(tester.getSize(listFinder).width, 400);
    expect(
      tester.widget<ScrollablePositionedList>(listFinder).padding!.left,
      0,
    );
  });
}
