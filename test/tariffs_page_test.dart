import 'dart:async';

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
import 'package:saobracaj/subscription/data/store_purchase_service.dart';
import 'package:saobracaj/subscription/data/subscription_repository.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/presentation/plan_features.dart';
import 'package:saobracaj/subscription/presentation/tariffs_page.dart';
import 'package:saobracaj/subscription/state_management/subscription_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

Tariff _tariff(String sku, TariffKind kind, int months, int priceRsd) => Tariff(
  sku: sku,
  kind: kind,
  months: months,
  priceRsd: priceRsd,
  appleProductId: 'at.gleb.saobracaj.$sku',
  googleProductId: sku,
  autoRenewing: months == 1,
);

/// Отдаёт каталог из `TARIFF_SEED` без обращения к серверу; личные данные
/// пустые — так витрину видит гость.
class _StubSubscriptionRepository extends SubscriptionRepository {
  _StubSubscriptionRepository({this.status = SubscriptionStatus.none})
    : super(
        GraphqlClient(TokenStorage()),
        FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  final SubscriptionStatus status;
  final redeemed = <String>[];

  @override
  Future<List<Tariff>> tariffs() async => [
    _tariff('basic_1m', TariffKind.basic, 1, 1190),
    _tariff('basic_6m', TariffKind.basic, 6, 2290),
    _tariff('basic_12m', TariffKind.basic, 12, 3990),
    _tariff('russian_1m', TariffKind.russian, 1, 1690),
    _tariff('russian_6m', TariffKind.russian, 6, 3490),
    _tariff('russian_12m', TariffKind.russian, 12, 5790),
  ];

  @override
  Future<SubscriptionStatus> mySubscription() async => status;

  @override
  Future<List<StorePurchase>> myPurchases() async => const [];

  @override
  Future<List<SubscriptionPeriod>> myPeriods() async => const [];

  @override
  Future<SubscriptionStatus> redeemPurchase({
    required StorePlatform platform,
    required String productId,
    required String receipt,
  }) async {
    redeemed.add('$productId:$receipt');
    return status;
  }

  @override
  Future<void> refreshGrants() async {}
}

/// Стор без стора: подменяет всё, что трогает плагин, поэтому тест идёт по
/// тому же пути, что телефон, — и на VM, где `in_app_purchase` не существует.
class _FakeStore extends StorePurchaseService {
  _FakeStore({this.platform = StorePlatform.google, this.available = true});

  @override
  final StorePlatform? platform;

  final bool available;
  final bought = <String>[];
  var restoreCalls = 0;
  final _events = StreamController<StorePurchaseEvent>.broadcast();

  @override
  bool get isSupported => platform != null;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final id in ids)
      StoreProduct(
        id: id,
        price: '$id price',
        rawPrice: 1000,
        currencyCode: 'RSD',
      ),
  ];

  @override
  Stream<StorePurchaseEvent> get purchases => _events.stream;

  @override
  Future<void> buy({
    required String productId,
    required bool autoRenewing,
  }) async {
    bought.add(productId);
  }

  @override
  Future<void> restore() async => restoreCalls++;

  @override
  Future<void> complete(StorePurchaseEvent event) async {}

  /// Сымитировать чек, который стор кладёт в очередь после оплаты.
  void emit(StorePurchaseEvent event) => _events.add(event);
}

/// Веб: плагина нет вовсе.
class _NoStore extends _FakeStore {
  _NoStore() : super(platform: null, available: false);
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
    StorePurchaseService? store,
  }) {
    getIt.registerFactory<SubscriptionBloc>(
      () => SubscriptionBloc(
        repository ?? _StubSubscriptionRepository(),
        store ?? _FakeStore(),
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

  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('цены приходят из стора, а не из справочных динаров', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(russianContent: false, authenticated: true));
    await tester.pumpAndSettle();

    // Стор назвал цену для каждого товара — витрина показывает именно её.
    expect(find.text('К оплате basic_1m price'), findsOneWidget);
    expect(find.text('К оплате basic_12m price'), findsOneWidget);
    // Справочная цена в динарах при живом сторе на карточках не всплывает.
    expect(find.textContaining('3\u00A0990 RSD'), findsNothing);
  });

  testWidgets('без стора витрина не продаёт, а отправляет в приложение', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(
      wrap(russianContent: false, authenticated: true, store: _NoStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подписка оформляется в приложении'), findsOneWidget);
    // Ни одной кнопки покупки — из веба к оплате мы не ведём вовсе.
    expect(find.text('Оформить'), findsNothing);
    expect(find.text('Восстановить покупки'), findsNothing);
    // Зато цены видны — справочные, в динарах.
    expect(find.text('К оплате 3\u00A0990 RSD'), findsOneWidget);
  });

  testWidgets('месячный подписан автопродлением, а годовой — экономией', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(russianContent: false, authenticated: true));
    await tester.pumpAndSettle();

    expect(
      find.text('Продлевается автоматически каждый месяц, пока вы не отмените'),
      findsOneWidget,
    );
    expect(
      find.text('Экономия 10\u00A0290 RSD против помесячной оплаты'),
      findsOneWidget,
    );
  });

  testWidgets('нажатие «Оформить» открывает окно оплаты стора', (tester) async {
    wide(tester);
    final store = _FakeStore();

    await tester.pumpWidget(
      wrap(russianContent: false, authenticated: true, store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Оформить'));
    // Не pumpAndSettle: пока стор не ответил, на кнопке крутится индикатор —
    // «устаканиться» этой странице теперь и не положено.
    await tester.pump();

    // Рекомендованная карточка — годовая: покупается её товар в этом сторе.
    expect(store.bought, ['basic_12m']);
  });

  testWidgets('чек из стора уходит на бэкенд и открывает подписку', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();
    final repo = _StubSubscriptionRepository();

    await tester.pumpWidget(
      wrap(
        russianContent: false,
        authenticated: true,
        repository: repo,
        store: store,
      ),
    );
    await tester.pumpAndSettle();

    store.emit(
      StorePurchaseEvent(
        productId: 'basic_12m',
        receipt: 'token-1',
        outcome: StorePurchaseOutcome.purchased,
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.redeemed, ['basic_12m:token-1']);
    expect(find.text('Спасибо! Подписка активна.'), findsOneWidget);
  });

  testWidgets('отменённая оплата не ошибка и ничего не показывает', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();
    final repo = _StubSubscriptionRepository();

    await tester.pumpWidget(
      wrap(
        russianContent: false,
        authenticated: true,
        repository: repo,
        store: store,
      ),
    );
    await tester.pumpAndSettle();

    store.emit(
      StorePurchaseEvent(
        productId: 'basic_12m',
        receipt: '',
        outcome: StorePurchaseOutcome.canceled,
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.redeemed, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('«Восстановить покупки» просит стор перевыдать чеки', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();

    await tester.pumpWidget(
      wrap(russianContent: false, authenticated: true, store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Восстановить покупки'));
    await tester.pumpAndSettle();

    expect(store.restoreCalls, 1);
  });

  // Отменить автопродление из приложения нельзя, и человек, который купит
  // год поверх месячной подписки, заплатит дважды, если его не предупредить.
  testWidgets('при активной автоподписке витрина предупреждает о двойной оплате', (
    tester,
  ) async {
    wide(tester);
    final repo = _StubSubscriptionRepository(
      status: SubscriptionStatus(
        active: true,
        kind: TariffKind.basic,
        endsAt: DateTime.now().add(const Duration(days: 20)),
        daysLeft: 20,
        autoRenewing: true,
        manageUrl: 'https://play.google.com/store/account/subscriptions',
      ),
    );

    await tester.pumpWidget(
      wrap(russianContent: false, authenticated: true, repository: repo),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Покупка на 6 или 12 месяцев её не отменит'),
      findsOneWidget,
    );
    expect(find.text('Управлять подпиской'), findsOneWidget);
  });

  testWidgets('русскоязычному надбавка предвыбрана', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap(russianContent: true, authenticated: true));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('К оплате russian_12m price'), findsOneWidget);
    expect(find.text('включено в цену'), findsOneWidget);
  });

  testWidgets(
    'выключенная надбавка возвращает базовые цены и называет доплату',
    (tester) async {
      wide(tester);

      await tester.pumpWidget(wrap(russianContent: true, authenticated: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('К оплате basic_12m price'), findsOneWidget);
      expect(find.text('+1\u00A0800 RSD'), findsOneWidget);
    },
  );

  testWidgets('гостю предлагают войти вместо покупки', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap(russianContent: false));
    await tester.pumpAndSettle();

    expect(find.text('Войдите, чтобы оформить подписку'), findsNWidgets(3));
    expect(find.text('Оформить'), findsNothing);
  });
  testWidgets('на телефоне сроки идут стопкой, самый выгодный первым', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(russianContent: false, authenticated: true));
    await tester.pumpAndSettle();

    // Порядок сверху вниз: 12 → 6 → 1. На узком экране порядок и есть
    // рекомендация — переключателя, который бы её нёс, здесь нет.
    final prices = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => t != null && t.startsWith('К оплате basic_'))
        .toList();
    expect(prices, [
      'К оплате basic_12m price',
      'К оплате basic_6m price',
      'К оплате basic_1m price',
    ]);
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
