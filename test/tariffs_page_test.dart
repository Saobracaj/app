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
import 'package:saobracaj/subscription/presentation/plan_features.dart';
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

  /// Что вернёт проверка промокода; `null` — отказ «не найден».
  PromoCodeInfo? promoInfo;
  final calls = <String>[];

  @override
  Future<PromoCodeInfo> checkPromoCode(String code) async {
    calls.add('check:$code');
    final promo = promoInfo;
    if (promo == null) throw GraphqlException('Промокод не найден');
    return promo;
  }
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

class _AuthedAuthBloc extends AuthBloc {
  _AuthedAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  tearDown(getIt.reset);

  Widget wrap({
    required bool russianContent,
    Locale? locale,
    bool authenticated = false,
    _StubSubscriptionRepository? repository,
  }) {
    getIt.registerFactory<SubscriptionBloc>(
      () => SubscriptionBloc(
        repository ?? _StubSubscriptionRepository(),
        _StubFeatureFlagsRepository(russianContent),
      ),
    );
    final storage = TokenStorage();
    final client = GraphqlClient(storage);
    final authRepository = AuthRepository(client, storage, AnalyticsService());
    final subscriptions = GraphqlSubscriptionClient(client, storage);
    final auth = authenticated
        ? _AuthedAuthBloc(authRepository, subscriptions)
        : _GuestAuthBloc(authRepository, subscriptions);
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

  testWidgets('промокод применяется и скидка видна на карточках', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _StubSubscriptionRepository()
      ..promoInfo = PromoCodeInfo(
        code: 'ABCD2345',
        discountPercent: 50,
        validUntil: DateTime(2026, 12, 31),
      );
    await tester.pumpWidget(
      wrap(russianContent: false, authenticated: true, repository: repo),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Промокод'),
      'abcd2345',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Применить'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('check:abcd2345'));
    expect(find.text('Промокод ABCD2345 — скидка 50%'), findsOneWidget);
    // Годовой: 3490 → 1745, полная цена рядом перечёркнутой подписью.
    expect(find.text('К оплате 1 745 RSD'), findsOneWidget);
    expect(find.text('3 490 RSD'), findsOneWidget);
    // Крупная цифра пересчитана от новой суммы: 1745 / 12 ≈ 145.
    expect(find.text('145 RSD'), findsOneWidget);

    // «Убрать» возвращает обычные цены.
    await tester.tap(find.text('Убрать'));
    await tester.pumpAndSettle();
    expect(find.text('К оплате 3 490 RSD'), findsOneWidget);
  });

  testWidgets('неизвестный промокод показывает причину под полем', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _StubSubscriptionRepository();
    await tester.pumpWidget(
      wrap(russianContent: false, authenticated: true, repository: repo),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Промокод'),
      'WRONG',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Применить'));
    await tester.pumpAndSettle();

    expect(find.text('Промокод не найден'), findsOneWidget);
    expect(find.text('К оплате 3 490 RSD'), findsOneWidget);
  });

  testWidgets('гостю поле промокода не показывается', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    expect(find.text('Промокод'), findsNothing);
  });

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

  testWidgets('на широком экране крутится вся страница, а не колонка', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    // Список во всю ширину окна: полоса прокрутки у правого края, колесо мыши
    // работает и над боковыми полями.
    expect(tester.getSize(find.byType(ListView)).width, 1600);
    // Содержимое при этом не растянуто — поля отданы в padding.
    expect(tester.getSize(find.byType(Table)).width, lessThanOrEqualTo(900));
  });

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
    expect(find.text('3 категории$freeCategoriesFootnoteMark'), findsWidgets);
    expect(find.text('все категории'), findsWidgets);
  });

  testWidgets('строка русских материалов повторяет выбор, а не сам выбор', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: true));
    await tester.pumpAndSettle();

    // Тумблер включён — таблица под ним не имеет права говорить «по выбору»:
    // выбор уже сделан, и строка называет его результат.
    expect(find.text('по выбору'), findsNothing);
    // Подпись легенды без своего кружка в таблице тоже не висит.
    expect(find.text('надбавка'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('по выбору'), findsNothing);
    // Выключенная надбавка — «не входит» в двух ячейках («Материалы на
    // русском» по подписке и «Чат с AI» бесплатно) плюс подпись легенды.
    expect(find.text('не входит'), findsNWidgets(3));
  });

  // «3 категории» без пояснения — загадка: какие именно? Звёздочка в ячейке и
  // такая же звёздочка у заголовка карточки, где категории названы поимённо,
  // связывают одно с другим.
  testWidgets('«N категорий» помечено звёздочкой, и сноска её объясняет', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    // Ни одной ячейки «3 категории» без звёздочки не осталось.
    expect(find.text('3 категории'), findsNothing);
    expect(find.text('3 категории$freeCategoriesFootnoteMark'), findsWidgets);

    // Сноска — заголовок карточки с названиями бесплатных категорий.
    final title = freeCategoriesFootnoteTitle();
    expect(title.startsWith(freeCategoriesFootnoteMark), isTrue);
    expect(find.text(title), findsOneWidget);
    expect(find.text('Что доступно бесплатно'), findsNothing);
  });

  // На узком экране таблица превращается в список — звёздочка нужна и там.
  testWidgets('в списочной вёрстке звёздочка тоже на месте', (tester) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    expect(find.byType(Table), findsNothing);
    expect(
      find.textContaining('3 категории$freeCategoriesFootnoteMark'),
      findsWidgets,
    );
    expect(find.text(freeCategoriesFootnoteTitle()), findsOneWidget);
  });

  testWidgets('кружки столбца стоят на одной вертикали с его заголовком', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    final marks = find.descendant(
      of: find.byType(Table),
      matching: find.byType(AccessMark),
    );
    final count = marks.evaluate().length;
    expect(count, planFeatureRows().length * 2);

    // Ровно две вертикали — по одной на столбец значений. Центрирование давало
    // столько же разных отступов, сколько разной длины подписей.
    final lefts = <double>{
      for (var i = 0; i < count; i++) tester.getTopLeft(marks.at(i)).dx,
    };
    expect(lefts.length, 2);

    // Заголовок столбца стоит над кружками, а не над серединой подписей.
    final sorted = lefts.toList()..sort();
    expect(tester.getTopLeft(find.text('БЕСПЛАТНО')).dx, closeTo(sorted[0], 1));
    expect(
      tester.getTopLeft(find.text('ПО ПОДПИСКЕ')).dx,
      closeTo(sorted[1], 1),
    );
  });
}
