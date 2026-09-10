import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/feature_flags_page.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран «Функции»: тумблер у каждой функции доступен всегда — и гостю, и
/// пользователю без подписки. Тир (вход/подписка) решает, *работает* ли
/// функция, а тумблер хранит выбор пользователя для этого устройства и
/// переживает вход в аккаунт и покупку подписки.

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

Future<FeatureFlagsRepository> _guestRepository() async {
  SharedPreferences.setMockInitialValues({});
  final storage = TokenStorage();
  final repository = FeatureFlagsRepository(
    _FakeClient(storage),
    storage,
    deviceLanguage: 'ru',
  );
  await repository.bootstrap();
  return repository;
}

Widget _app(FeatureFlagsRepository repository) {
  return EasyLocalization(
    useOnlyLangCode: true,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('ru'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => BlocProvider(
        create: (_) => FeatureFlagsBloc(repository)..add(FeatureFlagsStarted()),
        child: MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const FeatureFlagsPage(),
        ),
      ),
    ),
  );
}

Finder _tile(AppFeature feature) =>
    find.byKey(ValueKey('feature_tile_${feature.key}'));

SwitchListTile _switch(WidgetTester tester, AppFeature feature) =>
    tester.widget<SwitchListTile>(_tile(feature));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('гость видит рабочий тумблер и у функций «по входу», и у '
      'премиум-функций', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = await _guestRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    for (final feature in [AppFeature.groups, AppFeature.askAi]) {
      final tile = _switch(tester, feature);
      expect(tile.onChanged, isNotNull, reason: '${feature.key} без тумблера');
      expect(tile.value, isTrue);
      // Подсказка про вход/подписку остаётся — она объясняет, почему функция
      // пока не работает, но не блокирует выбор.
      expect(tile.subtitle, isNotNull);
    }
    expect(_switch(tester, AppFeature.groups).subtitle, isA<Text>());
    expect(
      find.descendant(
        of: _tile(AppFeature.askAi),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
    // Гостевая функция — без замка и подсказки.
    expect(_switch(tester, AppFeature.questionSearch).subtitle, isNull);
    expect(
      find.descendant(
        of: _tile(AppFeature.questionSearch),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );
  });

  testWidgets('выключение закрытой функции гостем сохраняется локально и '
      'держит функцию выключенной после входа', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = await _guestRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(_tile(AppFeature.groups));
    await tester.pumpAndSettle();

    expect(_switch(tester, AppFeature.groups).value, isFalse);
    expect(repository.snapshot.localEnabled(AppFeature.groups), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('feature.groups.enabled'), isFalse);

    // После входа тир выполнен, но локальный выбор — «выключено» — побеждает.
    final signedIn = FeatureFlagsSnapshot.resolve(
      localOverrides: repository.snapshot.localOverrides,
      grants: const {},
      authenticated: true,
    );
    expect(signedIn.isEnabled(AppFeature.groups), isFalse);
    expect(signedIn.isEnabled(AppFeature.supportChat), isTrue);
  });
}
