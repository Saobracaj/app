import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/domain/settings_section.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/presentation/profile_page.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/presentation/panel_page.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:saobracaj/theme/state_management/theme_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Тесты раскладки настроек: у каждого раздела свой адрес
/// (`/settings/appearance`, …). На широком экране адрес подменяет контент в
/// правой панели, меню слева остаётся на месте (задачи 1217350577802650,
/// 1217510064568188); сам `/settings` там сразу становится
/// `/settings/profile`, а разделы сменяются без анимации перехода
/// (задача 1217517553850759).

/// Клиент-заглушка: сеть в этих тестах не используется.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

/// Оборачивает [child] в локализацию с настоящими переводами и тему приложения.
Widget _localized({required Widget Function(BuildContext) builder}) {
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('sr'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(builder: builder),
  );
}

/// Экран настроек гостя со всеми нужными ему блоками, под настоящим роутером:
/// пункты меню теперь переходят по адресу раздела, поэтому проверять их без
/// навигации больше нельзя.
RoutemasterDelegate _delegate({String initialPath = '/settings'}) =>
    RoutemasterDelegate(
      routesBuilder: (_) => RouteMap(
        routes: {
          '/': (_) => Redirect(initialPath),
          '/settings': (_) => const MaterialPage(child: ProfilePage()),
          '/settings/:section': (data) {
            final section = SettingsSection.bySlug(
              data.pathParameters['section'],
            );
            if (section == null) return const Redirect('/settings');
            return PanelPage(child: ProfilePage(section: section));
          },
        },
      ),
    );

Widget _settingsApp({RoutemasterDelegate? delegate}) {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final router = delegate ?? _delegate();
  return _localized(
    builder: (context) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(
            AuthRepository(client, storage, AnalyticsService()),
            GraphqlSubscriptionClient(client, storage),
          ),
        ),
        BlocProvider(
          create: (_) =>
              FeatureFlagsBloc(FeatureFlagsRepository(client, storage)),
        ),
        BlocProvider(create: (_) => ThemeBloc()),
      ],
      child: MaterialApp.router(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
        routerDelegate: router,
        routeInformationParser: const RoutemasterParser(),
      ),
    ),
  );
}

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

ListTile _menuTile(WidgetTester tester, IconData icon) => tester.widget(
  find.ancestor(of: find.byIcon(icon), matching: find.byType(ListTile)),
);

/// Маршрут страницы, на которой лежит [finder].
TransitionRoute<void> _routeOf(WidgetTester tester, Finder finder) =>
    ModalRoute.of(tester.element(finder))! as TransitionRoute<void>;

/// Оболочка вкладок, как у домашнего экрана: тело — стек текущей вкладки, а
/// переключатель — кнопки по числу вкладок.
class _TabShell extends StatelessWidget {
  const _TabShell();

  @override
  Widget build(BuildContext context) {
    final pageState = IndexedPage.of(context);
    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < pageState.stacks.length; i++)
                TextButton(
                  key: ValueKey('tab$i'),
                  onPressed: () => pageState.index = i,
                  child: Text('tab$i'),
                ),
            ],
          ),
          Expanded(
            child: PageStackNavigator(
              key: ValueKey(pageState.index),
              stack: pageState.stacks[pageState.index],
            ),
          ),
        ],
      ),
    );
  }
}

/// Роутер с вкладками, как в приложении: настройки — вкладка домашнего экрана.
RoutemasterDelegate _tabbedDelegate() => RoutemasterDelegate(
  routesBuilder: (_) => RouteMap(
    routes: {
      '/': (_) => const IndexedPage(
        child: _TabShell(),
        paths: ['/home', '/settings'],
        backBehavior: TabBackBehavior.history,
      ),
      '/home': (_) => const MaterialPage(child: Center(child: Text('home'))),
      '/settings': (_) => const MaterialPage(child: ProfilePage()),
      '/settings/:section': (data) => PanelPage(
        child: ProfilePage(
          section: SettingsSection.bySlug(data.pathParameters['section']),
        ),
      ),
    },
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('широкий экран: по умолчанию справа карточка аккаунта', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(1440, 900));
    final router = _delegate();
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();

    // Меню слева и карточка аккаунта справа (гость — приглашение войти).
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    // Адрес сразу стал адресом раздела профиля: у `/settings` на широком
    // экране нет своего вида, а нажатие на «Профиль» иначе открывало бы поверх
    // тот же экран ещё раз.
    expect(router.currentConfiguration?.path, '/settings/profile');
  });

  testWidgets('широкий экран: раздел из адреса не подменяется на профиль', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(1440, 900));
    final router = _delegate(initialPath: '/settings/appearance');
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();

    // Под разделом в стеке лежит `/settings`, но уводить с открытого раздела
    // он не должен.
    expect(router.currentConfiguration?.path, '/settings/appearance');
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
  });

  testWidgets('широкий экран: раздел открывается без анимации перехода', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(1440, 900));
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    // Смена раздела — смена панели, а не экрана: у страницы раздела нулевая
    // длительность перехода в обе стороны.
    final route = _routeOf(tester, find.byType(SegmentedButton<ThemeMode>));
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('средний экран: у раздела нет стрелки «назад» на `/settings`', (
    tester,
  ) async {
    // 840–1200: двухпанельная раскладка ещё с AppBar (без боковой колонки).
    _setScreenSize(tester, const Size(1000, 800));
    final router = _delegate(initialPath: '/settings/appearance');
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    // Под разделом лежит `/settings`, но это тот же самый экран —
    // возвращаться на него некуда.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets(
    'широкий экран: пункт «Оформление» показывает раздел справа, без нового '
    'экрана',
    (tester) async {
      _setScreenSize(tester, const Size(1440, 900));
      final router = _delegate();
      await tester.pumpWidget(_settingsApp(delegate: router));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
      await tester.tap(find.byIcon(Icons.palette_outlined));
      await tester.pumpAndSettle();

      // Контент раздела появился в правой панели: переключатель темы виден,
      // карточка аккаунта (кнопка входа) ушла, а меню осталось на месте.
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(_menuTile(tester, Icons.palette_outlined).selected, isTrue);
      // …и у раздела появился собственный адрес.
      expect(router.currentConfiguration?.path, '/settings/appearance');
    },
  );

  testWidgets('широкий экран: адрес раздела открывает его сразу, с меню', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(1440, 900));
    final router = _delegate(initialPath: '/settings/appearance');
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    expect(_menuTile(tester, Icons.palette_outlined).selected, isTrue);
    // Меню слева никуда не делось — это то же самое состояние, что и после
    // нажатия пункта.
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('широкий экран: пункты переключаются между собой', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(1440, 900));
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    // Список фич сменил «Оформление» в той же панели.
    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    expect(find.byType(SwitchListTile), findsWidgets);
    expect(_menuTile(tester, Icons.tune).selected, isTrue);
    expect(_menuTile(tester, Icons.palette_outlined).selected, isFalse);
  });

  testWidgets('вкладка настроек на широком экране открывается на профиле', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(1440, 900));
    final router = _tabbedDelegate();
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration?.path, '/home');

    // Первый переход во вкладку: адрес — сразу раздел профиля, вкладка —
    // настройки.
    await tester.tap(find.byKey(const ValueKey('tab1')));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration?.path, '/settings/profile');
    expect(find.byType(FilledButton), findsOneWidget);

    // Выбор раздела внутри вкладки и возврат в неё через другую вкладку:
    // вкладка помнит открытый раздел, а не сбрасывается на профиль.
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration?.path, '/settings/appearance');
    await tester.tap(find.byKey(const ValueKey('tab0')));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration?.path, '/home');
    await tester.tap(find.byKey(const ValueKey('tab1')));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration?.path, '/settings/appearance');
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
  });

  testWidgets('вкладка настроек на телефоне остаётся списком', (tester) async {
    _setScreenSize(tester, const Size(400, 800));
    final router = _tabbedDelegate();
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab1')));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration?.path, '/settings');
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
  });

  testWidgets('телефон: прежний список настроек без правой панели', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(400, 800));
    final router = _delegate();
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();

    // Мобильная раскладка: список пунктов с шевронами, контент разделов не
    // встроен; адрес остаётся `/settings` — на телефоне это сам список.
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    expect(_menuTile(tester, Icons.palette_outlined).selected, isFalse);
    expect(router.currentConfiguration?.path, '/settings');
  });

  testWidgets('телефон: раздел — отдельный экран с обычным переходом', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(400, 800));
    final router = _delegate();
    await tester.pumpWidget(_settingsApp(delegate: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    // Новый экран поверх списка: адрес раздела, анимированный переход и
    // стрелка «назад» к списку.
    expect(router.currentConfiguration?.path, '/settings/appearance');
    final route = _routeOf(tester, find.byType(SegmentedButton<ThemeMode>));
    expect(route.transitionDuration, isNot(Duration.zero));
    expect(find.byType(BackButton), findsOneWidget);
  });
}
