import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
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
import 'package:saobracaj/subscription/presentation/paywall.dart';
import 'package:saobracaj/subscription/presentation/plan_features.dart';
import 'package:saobracaj/subscription/presentation/subscription_page.dart';
import 'package:saobracaj/subscription/presentation/tariffs_page.dart';
import 'package:saobracaj/subscription/state_management/subscription_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

Tariff _tariff(String sku, int months, int priceRsd) => Tariff(
  sku: sku,
  months: months,
  priceRsd: priceRsd,
  appleProductId: 'at.gleb.saobracaj.$sku',
  googleProductId: sku,
  autoRenewing: months == 1,
);

StorePurchase _purchase(String sku, int months, {required bool autoRenewing}) =>
    StorePurchase(
      id: 'purchase-$sku',
      platform: StorePlatform.google,
      sku: sku,
      months: months,
      productId: sku,
      transactionId: 'GPA.$sku',
      autoRenewing: autoRenewing,
      status: StorePurchaseStatus.active,
      purchasedAt: DateTime.now(),
    );

/// Отдаёт каталог из `TARIFF_SEED` без обращения к серверу; личные данные
/// пустые — так витрину видит гость.
class _StubSubscriptionRepository extends SubscriptionRepository {
  _StubSubscriptionRepository({
    this.status = SubscriptionStatus.none,
    this.purchases = const [],
  }) : super(
         GraphqlClient(TokenStorage()),
         FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
       );

  final SubscriptionStatus status;
  final List<StorePurchase> purchases;
  final redeemed = <String>[];

  /// Чем бэкенд отвечает на чек вместо права — когда тест проверяет отказ.
  GraphqlException? redeemError;

  /// Пока не завершён, бэкенд «думает» над чеком — так тест видит экран
  /// между закрытием окна стора и записью права.
  Completer<void>? redeemGate;

  @override
  Future<List<Tariff>> tariffs() async => [
    _tariff('premium_1m', 1, 1490),
    _tariff('premium_3m', 3, 2990),
    _tariff('premium_12m', 12, 4490),
  ];

  @override
  Future<SubscriptionStatus> mySubscription() async => status;

  @override
  Future<List<StorePurchase>> myPurchases() async => purchases;

  @override
  Future<List<SubscriptionPeriod>> myPeriods() async => const [];

  @override
  Future<SubscriptionStatus> redeemPurchase({
    required StorePlatform platform,
    required String productId,
    required String receipt,
  }) async {
    redeemed.add('$productId:$receipt');
    await redeemGate?.future;
    if (redeemError != null) throw redeemError!;
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

  /// Цены стора — те же суммы, что в справочном каталоге: иначе проценты
  /// экономии на витрине разошлись бы с арифметикой каталога, и тест ловил бы
  /// не витрину, а выдумку фейка.
  static const _rawPrices = {
    'premium_1m': 1490.0,
    'premium_3m': 2990.0,
    'premium_12m': 4490.0,
  };

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final id in ids)
      StoreProduct(
        id: id,
        price: '$id price',
        rawPrice: _rawPrices[id] ?? 1000,
        currencyCode: 'RSD',
      ),
  ];

  @override
  Stream<StorePurchaseEvent> get purchases => _events.stream;

  @override
  Future<void> buy({required String productId}) async {
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
    Locale? locale,
    bool authenticated = false,
    _StubSubscriptionRepository? repository,
    StorePurchaseService? store,
    Widget home = const TariffsPage(),
    Map<String, PageBuilder> routes = const {},
  }) {
    getIt.registerFactory<SubscriptionBloc>(
      () => SubscriptionBloc(
        repository ?? _StubSubscriptionRepository(),
        store ?? _FakeStore(),
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
      // Как в `main.dart`: без этого easy_localization склоняет по одному лишь
      // числу, и «12 месяцев» в переключателе становится «12 месяца».
      ignorePluralRules: false,
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
          // Роутер, а не `home`: после покупки витрина закрывает себя и
          // открывает экран подписки, и это должно быть видно тесту.
          // Сессия — над роутером, как в `main.dart`: её видит и страница
          // маршрута, и экран, открытый поверх неё императивно.
          return BlocProvider<AuthBloc>.value(
            value: auth,
            child: MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerDelegate: RoutemasterDelegate(
                routesBuilder: (_) => RouteMap(
                  routes: {
                    '/': (_) => MaterialPage(child: home),
                    '/subscription': (_) => const MaterialPage(
                      child: Scaffold(body: Text('экран подписки')),
                    ),
                    ...routes,
                  },
                ),
              ),
              routeInformationParser: const RoutemasterParser(),
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

  /// Переключить срок: подпись сегмента — это тот же `monthsLabel`, что и в
  /// каталоге.
  Future<void> pickTerm(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('цены приходят из стора, а не из справочных динаров', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    // Открыт рекомендованный срок, и цена на нём — та, что назвал стор.
    expect(find.text('premium_3m price'), findsOneWidget);
    // Справочная цена в динарах при живом сторе не всплывает.
    expect(find.textContaining('2 990 RSD'), findsNothing);
  });

  // Ради этого переключатель и заводился: сроков три, а карточка одна, и
  // экран не растёт вместе с каталогом.
  testWidgets('переключатель срока меняет карточку, а не длину экрана', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    expect(find.text('К оплате сейчас'), findsOneWidget);
    expect(find.text('premium_3m price'), findsOneWidget);

    await pickTerm(tester, '12 месяцев');

    expect(find.text('К оплате сейчас'), findsOneWidget);
    expect(find.text('premium_12m price'), findsOneWidget);
    expect(find.text('premium_3m price'), findsNothing);
  });

  // Овал переключателя должен переезжать, а не перескакивать: на середине
  // движения он уже не там, где был, но ещё не там, где будет.
  testWidgets('овал переключателя переезжает, а не перескакивает', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    final thumb = find.byKey(termThumbKey);
    final before = tester.getCenter(thumb).dx;

    await tester.tap(find.text('12 месяцев'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final middle = tester.getCenter(thumb).dx;

    await tester.pumpAndSettle();
    final after = tester.getCenter(thumb).dx;

    expect(middle, greaterThan(before));
    expect(middle, lessThan(after));
    // Доехал ровно под выбранный срок.
    expect(after, closeTo(tester.getCenter(find.text('12 месяцев')).dx, 1));
  });

  // Карточка едет вместе с овалом: на середине движения на экране обе — та,
  // что уходит, и та, что приходит.
  testWidgets('карточка переезжает вместе с переключателем', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('12 месяцев'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('premium_3m price'), findsOneWidget);
    expect(find.text('premium_12m price'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('premium_3m price'), findsNothing);
  });

  // Тот же выбор с другой стороны: карточку листают пальцем, а переключатель
  // едет следом.
  testWidgets('смахивание карточки переключает срок', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('premium_12m price'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(termThumbKey)).dx,
      closeTo(tester.getCenter(find.text('12 месяцев')).dx, 1),
    );
  });

  testWidgets('без стора витрина не продаёт, а отправляет в приложение', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true, store: _NoStore()));
    await tester.pumpAndSettle();

    expect(find.text('Подписка оформляется в приложении'), findsOneWidget);
    // Ни одной кнопки покупки — из веба к оплате мы не ведём вовсе.
    expect(find.textContaining('Оплатить'), findsNothing);
    expect(find.text('Оформить подписку'), findsNothing);
    expect(find.text('Восстановить покупки'), findsNothing);
    // Зато цены видны — справочные, в динарах.
    expect(find.text('2 990 RSD'), findsOneWidget);
  });

  // Разница между «спишется ещё раз через месяц» и «больше не спишется» —
  // единственная содержательная разница между сроками, и названа она словами,
  // а не выведена из мелкой подписи.
  testWidgets('тип платежа назван словами на самой карточке', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    expect(find.text('Разовый платёж · без автопродления'), findsOneWidget);
    // Значок уже сказал «без автопродления», срок назван в строке цены —
    // подписи под ценой у разового платежа нет.
    expect(find.textContaining('не списывается'), findsNothing);
    expect(find.textContaining('Доступ на'), findsNothing);

    await pickTerm(tester, '1 месяц');

    expect(find.text('Подписка · автопродление'), findsOneWidget);
    expect(
      find.textContaining('Продлевается автоматически каждый месяц'),
      findsOneWidget,
    );
  });

  // Кнопка называет ту же сумму, что и карточка: окно стора не должно
  // показывать ничего нового.
  testWidgets('кнопка повторяет сумму, а подписка называется подпиской', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
      findsOneWidget,
    );

    await pickTerm(tester, '1 месяц');

    // У автопродлеваемого пропуска «оплатить N» соврало бы: платежей будет
    // много.
    expect(
      find.widgetWithText(FilledButton, 'Оформить подписку'),
      findsOneWidget,
    );
  });

  // Экономия стоит рядом с ценой, и считать её надо в тех же деньгах. Без
  // стора это справочные динары — их и проверяем: сумму стора отформатировал
  // бы `intl`, и тест сверял бы форматтер сам с собой.
  testWidgets('экономия названа в тех же деньгах, что и цены', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true, store: _NoStore()));
    await tester.pumpAndSettle();
    await pickTerm(tester, '12 месяцев');

    expect(
      find.text('Экономия 13 390 RSD по сравнению с помесячной оплатой'),
      findsOneWidget,
    );

    // Месячному сравнивать себя не с чем — строки экономии у него нет.
    await pickTerm(tester, '1 месяц');
    expect(find.textContaining('Экономия'), findsNothing);
  });

  testWidgets('нажатие кнопки открывает окно оплаты стора', (tester) async {
    wide(tester);
    final store = _FakeStore();

    await tester.pumpWidget(wrap(authenticated: true, store: store));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
    );
    // Не pumpAndSettle: пока стор не ответил, на кнопке крутится индикатор —
    // «устаканиться» этой странице теперь и не положено.
    await tester.pump();

    // Открыт рекомендованный срок — покупается его товар в этом сторе.
    expect(store.bought, ['premium_3m']);
  });

  // Между нажатием и записью права проходит окно стора и запрос к бэкенду;
  // всё это время кнопка заперта и говорит, что происходит.
  testWidgets('после нажатия кнопка заперта и говорит, что платёж идёт', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();
    final repo = _StubSubscriptionRepository()..redeemGate = Completer();

    await tester.pumpWidget(
      wrap(authenticated: true, repository: repo, store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Обрабатываем платёж…'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Оплатить premium_3m price'), findsNothing);

    // Окно стора закрыто, чек ушёл на бэкенд, ответа ещё нет — кнопка всё ещё
    // занята: без этого экран выглядел бы так, будто ничего не происходит.
    store.emit(
      StorePurchaseEvent(
        productId: 'premium_3m',
        receipt: 'token-1',
        outcome: StorePurchaseOutcome.purchased,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(repo.redeemed, ['premium_3m:token-1']);
    expect(find.text('Обрабатываем платёж…'), findsOneWidget);
    expect(find.byType(TariffsPage), findsOneWidget);

    // Право записано — витрина закрывается.
    repo.redeemGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TariffsPage), findsNothing);
    expect(find.text('экран подписки'), findsOneWidget);
  });

  testWidgets('отмена в окне стора возвращает кнопку как была', (tester) async {
    wide(tester);
    final store = _FakeStore();

    await tester.pumpWidget(wrap(authenticated: true, store: store));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
    );
    await tester.pump();
    expect(find.text('Обрабатываем платёж…'), findsOneWidget);

    store.emit(
      StorePurchaseEvent(
        productId: 'premium_3m',
        receipt: '',
        outcome: StorePurchaseOutcome.canceled,
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('Обрабатываем платёж…'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  // Снэкбар гаснет за секунды, и человек, вернувшийся из окна стора, его не
  // увидит: ошибка стоит под кнопкой, пока не начнётся следующая попытка.
  testWidgets('отказ стора остаётся под кнопкой', (tester) async {
    wide(tester);
    final store = _FakeStore();

    await tester.pumpWidget(wrap(authenticated: true, store: store));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
    );
    await tester.pump();
    store.emit(
      StorePurchaseEvent(
        productId: 'premium_3m',
        receipt: '',
        outcome: StorePurchaseOutcome.failed,
        errorMessage: 'Карта отклонена',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Карта отклонена'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
          )
          .onPressed,
      isNotNull,
    );

    // Следующая попытка убирает старую ошибку.
    await tester.tap(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
    );
    await tester.pump();
    expect(find.text('Карта отклонена'), findsNothing);
  });

  testWidgets('чек из стора уходит на бэкенд и открывает экран подписки', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();
    final repo = _StubSubscriptionRepository();

    await tester.pumpWidget(
      wrap(authenticated: true, repository: repo, store: store),
    );
    await tester.pumpAndSettle();

    store.emit(
      StorePurchaseEvent(
        productId: 'premium_12m',
        receipt: 'token-1',
        outcome: StorePurchaseOutcome.purchased,
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.redeemed, ['premium_12m:token-1']);
    // Витрина закрыта, человек стоит на экране подписки, и благодарность
    // показана уже там.
    expect(find.byType(TariffsPage), findsNothing);
    expect(find.text('экран подписки'), findsOneWidget);
    expect(find.text('Спасибо! Подписка активна.'), findsOneWidget);
  });

  // Право не записано — покупка не активирована: витрина остаётся, ошибка
  // под кнопкой, а чек стору не подтверждается (это проверяет Bloc).
  testWidgets('отказ бэкенда при активации не уводит с витрины', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();
    final repo = _StubSubscriptionRepository()
      ..redeemError = GraphqlException('Чек не принят');

    await tester.pumpWidget(
      wrap(authenticated: true, repository: repo, store: store),
    );
    await tester.pumpAndSettle();

    store.emit(
      StorePurchaseEvent(
        productId: 'premium_3m',
        receipt: 'token-1',
        outcome: StorePurchaseOutcome.purchased,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TariffsPage), findsOneWidget);
    expect(find.text('Чек не принят'), findsOneWidget);
    expect(find.text('Обрабатываем платёж…'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Оплатить premium_3m price'),
      findsOneWidget,
    );
  });

  // Восстановление — не покупка: чек `restored` право открывает, но с витрины
  // никуда не уводит и «спасибо за покупку» не говорит.
  testWidgets('восстановленный чек не закрывает витрину', (tester) async {
    wide(tester);
    final store = _FakeStore();
    final repo = _StubSubscriptionRepository();

    await tester.pumpWidget(
      wrap(authenticated: true, repository: repo, store: store),
    );
    await tester.pumpAndSettle();

    store.emit(
      StorePurchaseEvent(
        productId: 'premium_12m',
        receipt: 'token-1',
        outcome: StorePurchaseOutcome.restored,
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.redeemed, ['premium_12m:token-1']);
    expect(find.byType(TariffsPage), findsOneWidget);
    expect(find.text('Спасибо! Подписка активна.'), findsNothing);
  });

  testWidgets('отменённая оплата не ошибка и ничего не показывает', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();
    final repo = _StubSubscriptionRepository();

    await tester.pumpWidget(
      wrap(authenticated: true, repository: repo, store: store),
    );
    await tester.pumpAndSettle();

    store.emit(
      StorePurchaseEvent(
        productId: 'premium_12m',
        receipt: '',
        outcome: StorePurchaseOutcome.canceled,
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.redeemed, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  // «Восстановить покупки» ушло с витрины, но никуда не делось: стор требует
  // этот путь, и он живёт в разделе «Подписка».
  testWidgets('«Восстановить покупки» живёт в разделе «Подписка»', (
    tester,
  ) async {
    wide(tester);
    final store = _FakeStore();

    await tester.pumpWidget(
      wrap(
        authenticated: true,
        store: store,
        home: const SubscriptionContent(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Восстановить покупки'));
    await tester.pumpAndSettle();

    expect(store.restoreCalls, 1);
  });

  // Витрина открыта при действующей подписке (из настроек, по ссылке). Второй
  // пропуск не продаём: его срок лишь встал бы в очередь, а месячные списания
  // продолжились бы. Вместо прежнего предупреждения — подпись «текущий тариф»
  // на действующем сроке, запертые кнопки покупки и кнопка в стор.
  testWidgets('при действующей автоподписке витрина показывает текущий тариф', (
    tester,
  ) async {
    wide(tester);
    final repo = _StubSubscriptionRepository(
      status: SubscriptionStatus(
        active: true,
        endsAt: DateTime.now().add(const Duration(days: 20)),
        daysLeft: 20,
        autoRenewing: true,
        manageUrl: 'https://play.google.com/store/account/subscriptions',
      ),
      purchases: [_purchase('premium_1m', 1, autoRenewing: true)],
    );

    await tester.pumpWidget(wrap(authenticated: true, repository: repo));
    await tester.pumpAndSettle();

    // Прежнего предупреждения нет; открыт срок действующего тарифа.
    expect(find.textContaining('её не отменит'), findsNothing);
    expect(find.text('Текущий тариф'), findsOneWidget);
    expect(find.text('Управлять подпиской'), findsOneWidget);
    expect(find.textContaining('Следующее списание'), findsOneWidget);
    expect(find.text('Оформить подписку'), findsNothing);

    // Другие сроки — с запертой кнопкой покупки. Переезд с первой страницы
    // сразу на третью идёт через ещё не измеренную страницу — листалка
    // должна довезти карточку, а не остаться на первой.
    await tester.tap(find.text('12 месяцев'));
    await tester.pumpAndSettle();
    final buy = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Оплатить premium_12m price'),
    );
    expect(buy.onPressed, isNull);
    expect(find.text('Управлять подпиской'), findsNothing);
  });

  // Разовый пропуск стор не продлевает — кнопки в стор нет, но срок подписан,
  // а покупать поверх него тоже нельзя.
  testWidgets('при действующем разовом пропуске кнопки покупки заперты', (
    tester,
  ) async {
    wide(tester);
    final repo = _StubSubscriptionRepository(
      status: SubscriptionStatus(
        active: true,
        endsAt: DateTime.now().add(const Duration(days: 300)),
        daysLeft: 300,
      ),
      purchases: [_purchase('premium_12m', 12, autoRenewing: false)],
    );

    await tester.pumpWidget(wrap(authenticated: true, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Текущий тариф'), findsOneWidget);
    expect(find.textContaining('действует до'), findsOneWidget);
    expect(find.text('Управлять подпиской'), findsNothing);
    expect(find.text('Оплатить premium_12m price'), findsNothing);

    await tester.tap(find.text('1 месяц'));
    await tester.pumpAndSettle();
    final buy = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Оформить подписку'),
    );
    expect(buy.onPressed, isNull);
  });

  // Тариф один: русские материалы входят в любой пропуск, тумблера и второго
  // ряда цен нет. Значок «Популярный» стоит на рекомендованном сроке, процент
  // экономии — на длинном.
  testWidgets('один Premium: без тумблера, со значками на сроках', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNothing);
    expect(find.text('Популярный'), findsOneWidget);
    expect(find.text('−75%'), findsOneWidget);
    expect(find.text('Материалы на русском'), findsOneWidget);
    // Якорь про пересдачу и обещание продления с витрины убраны — они не
    // помогали выбрать срок, а места занимали больше, чем цены.
    expect(find.textContaining('5 800 RSD'), findsNothing);
    expect(find.textContaining('ещё один месяц доступа'), findsNothing);
  });

  // Строка о бесплатном уровне свелась к одной ссылке: «3 категории открыты
  // бесплатно и полностью» на витрине ничего не решало, а сравнение за
  // ссылкой называет их полностью.
  testWidgets('о бесплатном уровне — только ссылка на сравнение', (
    tester,
  ) async {
    wide(tester);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    expect(
      find.textRange.ofSubstring('Что доступно без подписки'),
      findsOneWidget,
    );
    expect(find.textContaining('открыты бесплатно'), findsNothing);
    expect(find.textContaining('3 категории'), findsNothing);
  });

  // Раздел «Подписка» называет тариф полностью — со сроком и типом платежа:
  // «Premium» без них не говорит, за что заплачено и продлится ли оно само.
  testWidgets('текущий тариф назван со сроком и типом платежа', (tester) async {
    wide(tester);
    final oneOff = _StubSubscriptionRepository(
      status: SubscriptionStatus(
        active: true,
        endsAt: DateTime.now().add(const Duration(days: 80)),
        daysLeft: 80,
      ),
      purchases: [_purchase('premium_3m', 3, autoRenewing: false)],
    );

    await tester.pumpWidget(
      wrap(
        authenticated: true,
        repository: oneOff,
        home: const SubscriptionPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium, 3 месяца'), findsOneWidget);
    // Разовый платёж никто не продлит — тумблер писем-напоминаний на месте,
    // и подпись под ним не рассуждает про автопродление.
    expect(find.text('Письма-напоминания'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.textContaining('Автопродлеваемую'), findsNothing);
  });

  testWidgets('автопродлеваемая подписка названа подпиской, без напоминаний', (
    tester,
  ) async {
    wide(tester);
    final renewing = _StubSubscriptionRepository(
      status: SubscriptionStatus(
        active: true,
        endsAt: DateTime.now().add(const Duration(days: 20)),
        daysLeft: 20,
        autoRenewing: true,
      ),
      purchases: [_purchase('premium_1m', 1, autoRenewing: true)],
    );
    await tester.pumpWidget(
      wrap(
        authenticated: true,
        repository: renewing,
        home: const SubscriptionPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium, подписка на 1 месяц'), findsOneWidget);
    // Подписку продлит стор — напоминания о конце срока ей не нужны.
    expect(find.text('Письма-напоминания'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  // Право, выданное оператором, покупкой не подкреплено — срока у него нет,
  // и название остаётся коротким, а не выдуманным.
  testWidgets('тариф без покупки в сторе называется просто Premium', (
    tester,
  ) async {
    wide(tester);
    final repo = _StubSubscriptionRepository(
      status: SubscriptionStatus(
        active: true,
        endsAt: DateTime.now().add(const Duration(days: 30)),
        daysLeft: 30,
      ),
    );

    await tester.pumpWidget(
      wrap(
        authenticated: true,
        repository: repo,
        home: const SubscriptionPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('гостю предлагают войти вместо покупки', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Карточка одна — и приглашение войти на ней одно.
    expect(find.text('Войдите, чтобы оформить подписку'), findsOneWidget);
    expect(find.textContaining('Оплатить'), findsNothing);
  });

  testWidgets('на телефоне сроки идут по возрастанию в переключателе', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(authenticated: true));
    await tester.pumpAndSettle();

    // Сравнивать сроки человек будет слева направо, и «12 месяцев» должно
    // стоять после «1 месяц», а не первым как рекомендация.
    final terms = ['1 месяц', '3 месяца', '12 месяцев'];
    final xs = [for (final t in terms) tester.getCenter(find.text(t)).dx];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));

    // Таблица сравнения на самой витрине больше не стоит — она за ссылкой.
    expect(find.byType(Table), findsNothing);
  });

  // Подробное сравнение нужно единицам, поэтому оно за ссылкой. Но дойти до
  // него должно быть можно, и звёздочка с её сноской обязаны ехать вместе.
  testWidgets('сравнение с бесплатным открывается шторкой', (tester) async {
    wide(tester);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // На самой витрине «Объяснения к вопросам» есть — строкой перечня, но
    // без сравнения с бесплатным уровнем.
    expect(find.byType(Table), findsNothing);
    expect(find.text('Почему верен именно этот ответ'), findsNothing);

    await tester.tapOnText(
      find.textRange.ofSubstring('Что доступно без подписки'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Почему верен именно этот ответ'), findsOneWidget);
    // Бесплатный уровень — те же функции на трёх категориях.
    expect(find.text('3 категории$freeCategoriesFootnoteMark'), findsWidgets);
    expect(find.text('все категории'), findsWidgets);
    // Ни одной ячейки «3 категории» без звёздочки, и сноска на месте.
    expect(find.text('3 категории'), findsNothing);
    expect(find.text(freeCategoriesFootnoteTitle()), findsOneWidget);
  });

  testWidgets('кружки столбца стоят на одной вертикали с его заголовком', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tapOnText(
      find.textRange.ofSubstring('Что доступно без подписки'),
    );
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

  // Сербский и английский длиннее русского в подписях сроков, а узкий экран —
  // самое тесное место для переключателя из трёх кнопок: и то и другое ловит
  // переполнения, которых не видно на русском десктопе.
  for (final locale in const [Locale('sr'), Locale('en')]) {
    for (final width in const [390.0, 700.0]) {
      testWidgets(
        'вёрстка держится: ${locale.languageCode}, ширина ${width.toInt()}',
        (tester) async {
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(wrap(locale: locale));
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

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Список во всю ширину окна: полоса прокрутки у правого края, колесо мыши
    // работает и над боковыми полями.
    expect(tester.getSize(find.byType(ListView)).width, 1600);
    // Содержимое при этом не растянуто — поля отданы в padding: колонка
    // шириной 1000 в окне 1600 начинается не раньше 300-й точки.
    expect(
      tester.getTopLeft(find.text('К оплате сейчас')).dx,
      greaterThanOrEqualTo(300),
    );
  });

  // Задача 1218209972696841: «назад» с витрины, открытой из гейта, ведёт
  // ровно на предыдущий экран. Гейт — карточка закрытого контента; в тесте
  // она стоит на экране «Подписка», у которого есть свой адрес и свой
  // '…/tariffs' в таблице маршрутов.
  Widget gate() => const Scaffold(
    body: LockedContentCard(
      source: PaywallSource.explanation,
      title: 'Объяснение',
      body: 'Почему так',
    ),
  );

  Finder gateCta() => find.descendant(
    of: find.byType(LockedContentCard),
    matching: find.byType(FilledButton),
  );

  testWidgets('тарифы открываются поверх экрана с гейтом, «назад» — на него', (
    tester,
  ) async {
    wide(tester);
    await tester.pumpWidget(
      wrap(
        authenticated: true,
        home: const Scaffold(body: Text('главная')),
        routes: {
          '/subscription': (_) => MaterialPage(child: gate()),
          '/subscription/tariffs': (_) =>
              const MaterialPage(child: TariffsPage()),
        },
      ),
    );
    await tester.pumpAndSettle();
    Routemaster.of(tester.element(find.text('главная'))).push('/subscription');
    await tester.pumpAndSettle();
    expect(find.byType(LockedContentCard), findsOneWidget);

    await tester.tap(gateCta());
    await tester.pumpAndSettle();

    // Витрина лежит поверх гейта, а не на месте всего стека.
    expect(find.byType(TariffsPage), findsOneWidget);
    expect(
      RouteData.of(tester.element(find.byType(TariffsPage))).path,
      '/subscription/tariffs',
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(TariffsPage), findsNothing);
    expect(find.byType(LockedContentCard), findsOneWidget);
    expect(find.text('главная'), findsNothing);
    expect(
      RouteData.of(tester.element(find.byType(LockedContentCard))).path,
      '/subscription',
    );
  });

  testWidgets('с экрана без адреса тарифы открываются поверх него же', (
    tester,
  ) async {
    // Экран, открытый императивно (как предпросмотр вопроса), адреса не
    // имеет — витрина всё равно ложится поверх него, и «назад» ведёт на него.
    wide(tester);
    await tester.pumpWidget(
      wrap(authenticated: true, home: const Scaffold(body: Text('главная'))),
    );
    await tester.pumpAndSettle();
    final home = tester.element(find.text('главная'));
    Navigator.of(
      home,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute(builder: (_) => gate()));
    await tester.pumpAndSettle();

    await tester.tap(gateCta());
    await tester.pumpAndSettle();
    expect(find.byType(TariffsPage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(TariffsPage), findsNothing);
    expect(find.byType(LockedContentCard), findsOneWidget);
    expect(find.text('главная'), findsNothing);
  });
}
