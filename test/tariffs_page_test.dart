import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/subscription/data/subscription_repository.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/presentation/tariffs_page.dart';
import 'package:saobracaj/subscription/state_management/subscription_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отдаёт каталог из `TARIFF_SEED` без обращения к серверу; личные данные
/// пустые — так витрину видит гость.
class _StubSubscriptionRepository extends SubscriptionRepository {
  _StubSubscriptionRepository()
    : super(
        GraphqlClient(TokenStorage()),
        FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  @override
  Future<List<Tariff>> tariffs() async => const [
    Tariff(sku: 'basic_1m', kind: TariffKind.basic, months: 1, priceRsd: 990),
    Tariff(sku: 'basic_6m', kind: TariffKind.basic, months: 6, priceRsd: 1990),
    Tariff(
      sku: 'basic_12m',
      kind: TariffKind.basic,
      months: 12,
      priceRsd: 3490,
    ),
    Tariff(
      sku: 'russian_1m',
      kind: TariffKind.russian,
      months: 1,
      priceRsd: 1490,
    ),
    Tariff(
      sku: 'russian_6m',
      kind: TariffKind.russian,
      months: 6,
      priceRsd: 2990,
    ),
    Tariff(
      sku: 'russian_12m',
      kind: TariffKind.russian,
      months: 12,
      priceRsd: 4990,
    ),
  ];

  @override
  Future<SubscriptionStatus> mySubscription() async => SubscriptionStatus.none;

  @override
  Future<List<Order>> myOrders() async => const [];

  @override
  Future<List<SubscriptionPeriod>> myPeriods() async => const [];
}

/// Локальный тумблер русских материалов — тот самый, по которому витрина
/// предвыбирает надбавку.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository(this._russian)
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool _russian;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {AppFeature.russianContent.key: _russian},
    grants: const {},
    authenticated: false,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

class _GuestAuthBloc extends AuthBloc {
  _GuestAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  tearDown(getIt.reset);

  Widget wrap({required bool russianContent, Locale? locale}) {
    getIt.registerFactory<SubscriptionBloc>(
      () => SubscriptionBloc(
        _StubSubscriptionRepository(),
        _StubFeatureFlagsRepository(russianContent),
      ),
    );
    final storage = TokenStorage();
    final client = GraphqlClient(storage);
    final auth = _GuestAuthBloc(
      AuthRepository(client, storage, AnalyticsService()),
      GraphqlSubscriptionClient(client, storage),
    );
    return EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: locale ?? const Locale('ru'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) {
          // Как в `main.dart`: без этого `intl` форматирует суммы по en_US.
          Intl.defaultLocale = context.locale.toLanguageTag();
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: BlocProvider<AuthBloc>.value(
              value: auth,
              child: const TariffsPage(),
            ),
          );
        },
      ),
    );
  }

  testWidgets('все три срока видны сразу, ценой за месяц', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    // Приманка и цель на экране одновременно — иначе разрыв не увидеть.
    expect(find.text('990 RSD'), findsOneWidget);
    expect(find.text('332 RSD'), findsOneWidget);
    expect(find.text('291 RSD'), findsOneWidget);
    // Полная сумма — подписью, а не главной цифрой.
    expect(find.text('К оплате 3\u00A0490 RSD'), findsOneWidget);
    expect(find.text('−71%'), findsOneWidget);
  });

  testWidgets('месячный подписан ручным продлением, а не экономией', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    expect(
      find.text('Через месяц придётся оплачивать заново, вручную'),
      findsOneWidget,
    );
    expect(
      find.text('Экономия 8\u00A0390 RSD против помесячной оплаты'),
      findsOneWidget,
    );
  });

  testWidgets('русскоязычному надбавка предвыбрана', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: true));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    // Цены — из семейства с русским.
    expect(find.text('416 RSD'), findsOneWidget);
    expect(find.text('включено в цену'), findsOneWidget);
  });

  testWidgets(
    'выключенная надбавка возвращает базовые цены и называет доплату',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(russianContent: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('291 RSD'), findsOneWidget);
      expect(find.text('+1\u00A0500 RSD'), findsOneWidget);
    },
  );

  testWidgets('гостю предлагают войти вместо покупки', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    expect(find.text('Войдите, чтобы оформить заказ'), findsNWidgets(3));
    expect(find.text('Выбрать'), findsNothing);
  });

  testWidgets('на телефоне сроки идут стопкой, самый выгодный первым', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    // Порядок сверху вниз: 12 → 6 → 1. На узком экране порядок и есть
    // рекомендация — переключателя, который бы её нёс, здесь нет.
    final prices = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => t == '291 RSD' || t == '332 RSD' || t == '990 RSD')
        .toList();
    expect(prices, ['291 RSD', '332 RSD', '990 RSD']);
    // Таблица на такой ширине не показывается — вместо неё карточки-списки.
    expect(find.byType(Table), findsNothing);
  });

  // Сербский и английский длиннее русского в подписях тарифов, а планшетная
  // ширина — самая тесная для трёхколоночной таблицы: и то и другое ловит
  // переполнения, которых не видно на русском десктопе.
  for (final locale in const [Locale('sr'), Locale('en')]) {
    for (final width in const [390.0, 700.0]) {
      testWidgets(
        'вёрстка держится: ${locale.languageCode}, ширина ${width.toInt()}',
        (tester) async {
          tester.view.physicalSize = Size(width, 3600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(wrap(russianContent: false, locale: locale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('таблица объясняет разницу объёмом, а не галочками', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    expect(find.text('Объяснения к вопросам'), findsOneWidget);
    // Бесплатный уровень — те же функции на трёх категориях.
    expect(find.text('3 категории'), findsWidgets);
    expect(find.text('все категории'), findsWidgets);
  });
}
