// Одноразовый превью-рендер витрины тарифов в PNG (не тест поведения):
//   flutter test tool/preview_tariffs_test.dart
// Скриншоты: build/tariffs_preview/*.png
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/subscription/data/store_purchase_service.dart';
import 'package:saobracaj/subscription/data/subscription_repository.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/presentation/tariffs_page.dart';
import 'package:saobracaj/subscription/state_management/subscription_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:saobracaj/theme/state_management/theme_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Tariff _tariff(String sku, int months, int priceRsd) => Tariff(
  sku: sku,
  months: months,
  priceRsd: priceRsd,
  appleProductId: 'at.gleb.saobracaj.$sku',
  googleProductId: sku,
  autoRenewing: months == 1,
);

class _Repository extends SubscriptionRepository {
  _Repository()
    : super(
        GraphqlClient(TokenStorage()),
        FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  @override
  Future<List<Tariff>> tariffs() async => [
    _tariff('premium_1m', 1, 1490),
    _tariff('premium_3m', 3, 2990),
    _tariff('premium_12m', 12, 4490),
  ];

  @override
  Future<SubscriptionStatus> mySubscription() async => SubscriptionStatus.none;

  @override
  Future<List<StorePurchase>> myPurchases() async => const [];

  @override
  Future<List<SubscriptionPeriod>> myPeriods() async => const [];

  @override
  Future<void> refreshGrants() async {}
}

/// Стор с сербскими ценами витрины — теми, что заведены в App Store Serbia.
class _Store extends StorePurchaseService {
  static const _prices = {
    'premium_1m': (12.99, '12,99 €'),
    'premium_3m': (24.99, '24,99 €'),
    'premium_12m': (37.99, '37,99 €'),
  };

  @override
  StorePlatform? get platform => StorePlatform.apple;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final id in ids)
      if (_prices[id.split('.').last] case final price?)
        StoreProduct(
          id: id,
          price: price.$2,
          rawPrice: price.$1,
          currencyCode: 'EUR',
        ),
  ];

  @override
  Stream<StorePurchaseEvent> get purchases =>
      const Stream<StorePurchaseEvent>.empty();

  @override
  Future<void> buy({
    required String productId,
    required bool autoRenewing,
  }) async {}

  @override
  Future<void> restore() async {}

  @override
  Future<void> complete(StorePurchaseEvent event) async {}
}

class _AuthedAuthBloc extends AuthBloc {
  _AuthedAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

Future<void> _loadFonts() async {
  final data = File('assets/fonts/Inter-400.ttf').readAsBytesSync();
  final bold = File('assets/fonts/Inter-700.ttf').readAsBytesSync();
  for (final family in ['Inter', 'Roboto', 'FlutterTest', 'Ahem']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(data)))
      ..addFont(Future.value(ByteData.sublistView(bold)));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
    Directory('build/tariffs_preview').createSync(recursive: true);
  });

  tearDown(getIt.reset);

  for (final (name, size, brightness, term) in [
    ('phone-light', const Size(390, 900), Brightness.light, null),
    ('phone-dark', const Size(390, 900), Brightness.dark, null),
    ('phone-light-1m', const Size(390, 900), Brightness.light, '1 месяц'),
    ('phone-light-12m', const Size(390, 900), Brightness.light, '12 месяцев'),
    ('tablet-light', const Size(760, 720), Brightness.light, null),
    ('desktop-dark', const Size(1180, 720), Brightness.dark, null),
  ]) {
    testWidgets('превью тарифов $name', (tester) async {
      // Не `setSurfaceSize`: он меняет поверхность рендера, но не
      // `view.physicalSize`, из которого считается MediaQuery, — телефон тогда
      // рисуется широкой раскладкой, ужатой в 390 точек.
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      getIt.registerFactory<SubscriptionBloc>(
        () => SubscriptionBloc(_Repository(), _Store()),
      );
      final storage = TokenStorage();
      final client = GraphqlClient(storage);
      final auth = _AuthedAuthBloc(
        AuthRepository(client, storage, AnalyticsService()),
        GraphqlSubscriptionClient(client, storage),
      );

      await tester.pumpWidget(
        EasyLocalization(
          useOnlyLangCode: true,
          ignorePluralRules: false,
          supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
          fallbackLocale: const Locale('ru'),
          startLocale: const Locale('ru'),
          saveLocale: false,
          path: 'assets/translations',
          assetLoader: const CodegenLoader(),
          child: Builder(
            builder: (context) {
              Intl.defaultLocale = context.locale.toLanguageTag();
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                theme: buildAppTheme(
                  ColorScheme.fromSeed(
                    seedColor: kDefaultSeedColor,
                    brightness: brightness,
                  ),
                ),
                home: BlocProvider<AuthBloc>.value(
                  value: auth,
                  child: const RepaintBoundary(
                    key: ValueKey('shot'),
                    child: TariffsPage(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (term != null) {
        await tester.tap(find.text(term));
        await tester.pumpAndSettle();
      }

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('shot')),
      );
      final image = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        return img.toByteData(format: ui.ImageByteFormat.png);
      });
      File('build/tariffs_preview/$name.png')
          .writeAsBytesSync(image!.buffer.asUint8List(), flush: true);
      // ignore: avoid_print
      print('PREVIEW build/tariffs_preview/$name.png');
    });
  }
}
