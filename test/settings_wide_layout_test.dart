import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/presentation/profile_page.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:saobracaj/theme/state_management/theme_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Тесты широкой раскладки настроек: пункт левого меню не открывает отдельный
/// экран, а подменяет контент в правой панели (задача 1217350577802650).

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

/// Экран настроек гостя со всеми нужными ему блоками. Роутера нет намеренно:
/// переключение разделов на широком экране не должно трогать навигацию —
/// попытка перехода уронила бы тест.
Widget _settingsApp() {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  return _localized(
    builder: (context) => MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(
              AuthRepository(client, storage),
              GraphqlSubscriptionClient(client, storage),
            ),
          ),
          BlocProvider(
            create: (_) => FeatureFlagsBloc(
              FeatureFlagsRepository(client, storage),
            ),
          ),
          BlocProvider(create: (_) => ThemeBloc()),
        ],
        child: const ProfilePage(),
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

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('широкий экран: по умолчанию справа карточка аккаунта', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(1440, 900));
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    // Меню слева и карточка аккаунта справа (гость — приглашение войти).
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets(
    'широкий экран: пункт «Оформление» показывает раздел справа, без нового '
    'экрана',
    (tester) async {
      _setScreenSize(tester, const Size(1440, 900));
      await tester.pumpWidget(_settingsApp());
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
    },
  );

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

  testWidgets('телефон: прежний список настроек без правой панели', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(400, 800));
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    // Мобильная раскладка: список пунктов с шевронами, контент разделов не
    // встроен.
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    expect(_menuTile(tester, Icons.palette_outlined).selected, isFalse);
  });
}
