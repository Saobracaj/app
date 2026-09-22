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
import 'package:saobracaj/subscription/presentation/lava_manage_sheet.dart';
import 'package:saobracaj/subscription/presentation/lava_return_page.dart';
import 'package:saobracaj/subscription/presentation/subscription_page.dart';
import 'package:saobracaj/subscription/presentation/tariff_formatting.dart';
import 'package:saobracaj/subscription/presentation/tariffs_page.dart';
import 'package:saobracaj/subscription/state_management/subscription_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Оплата рублями через lava.top — только веб: витрина без стора, кнопка
/// «Оплатить российской картой», возврат со страницы оплаты, управление
/// подпиской с явной отменой и запрет новой покупки, пока подписка действует.

Tariff _tariff(String sku, int months, int priceRsd, int priceRub) => Tariff(
  sku: sku,
  months: months,
  priceRsd: priceRsd,
  appleProductId: 'at.gleb.saobracaj.$sku',
  googleProductId: sku,
  autoRenewing: months == 1,
  priceRub: priceRub,
  lavaAvailable: true,
);

final _endsAt = DateTime(2026, 10, 22, 12);

/// Действующая (или отменённая) подписка lava.top на месяц.
SubscriptionStatus _lavaStatus({required bool cancelled}) => SubscriptionStatus(
  active: true,
  endsAt: _endsAt,
  daysLeft: 30,
  autoRenewing: !cancelled,
  platform: cancelled ? null : StorePlatform.lava,
  lavaSubscription: LavaSubscription(
    contractId: 'contract-1',
    sku: 'premium_1m',
    months: 1,
    priceRub: 1190,
    cancelled: cancelled,
    endsAt: _endsAt,
    nextChargeAt: cancelled ? null : _endsAt,
  ),
  purchaseBlockedUntil: _endsAt,
);

StorePurchase _lavaPurchase({required bool autoRenewing}) => StorePurchase(
  id: 'purchase-lava',
  platform: StorePlatform.lava,
  sku: 'premium_1m',
  months: 1,
  productId: 'offer-1m',
  transactionId: 'contract-1',
  autoRenewing: autoRenewing,
  status: StorePurchaseStatus.active,
  purchasedAt: DateTime.now(),
  expiresAt: _endsAt,
);

class _StubRepository extends SubscriptionRepository {
  _StubRepository({
    this.status = SubscriptionStatus.none,
    this.purchases = const [],
  }) : super(
         GraphqlClient(TokenStorage()),
         FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
       );

  SubscriptionStatus status;
  List<StorePurchase> purchases;

  /// Созданные счета: sku и адрес возврата.
  final created = <(String sku, String returnUrl)>[];

  /// Чем бэкенд отвечает на создание счёта, если не счётом.
  GraphqlException? createError;

  /// Ответы на опрос счёта по порядку; последний повторяется.
  List<LavaInvoiceStatus> pollAnswers = const [LavaInvoiceStatus.paid];
  var polls = 0;
  var cancels = 0;

  @override
  Future<List<Tariff>> tariffs() async => [
    _tariff('premium_1m', 1, 1490, 1190),
    _tariff('premium_3m', 3, 2990, 2390),
    _tariff('premium_12m', 12, 4490, 3590),
  ];

  @override
  Future<SubscriptionStatus> mySubscription() async => status;

  @override
  Future<List<StorePurchase>> myPurchases() async => purchases;

  @override
  Future<List<SubscriptionPeriod>> myPeriods() async => const [];

  @override
  Future<LavaInvoice> createLavaInvoice({
    required String sku,
    required String returnUrl,
  }) async {
    created.add((sku, returnUrl));
    if (createError != null) throw createError!;
    return LavaInvoice(
      id: 'contract-new',
      sku: sku,
      status: LavaInvoiceStatus.pending,
      paymentUrl: 'https://app.lava.top/pay/$sku',
      amountRub: 2390,
    );
  }

  @override
  Future<LavaInvoice> lavaInvoice(String id) async {
    final answer = pollAnswers[polls.clamp(0, pollAnswers.length - 1)];
    polls++;
    return LavaInvoice(
      id: id,
      sku: 'premium_3m',
      status: answer,
      paymentUrl: answer == LavaInvoiceStatus.paid ? null : 'https://x',
    );
  }

  @override
  Future<SubscriptionStatus> cancelLavaSubscription() async {
    cancels++;
    status = _lavaStatus(cancelled: true);
    purchases = [_lavaPurchase(autoRenewing: false)];
    return status;
  }

  @override
  Future<void> refreshGrants() async {}
}

/// Веб: стора нет, а переход на страницу оплаты перехватывается.
class _WebStore extends StorePurchaseService {
  final opened = <Uri>[];

  @override
  StorePlatform? get platform => null;

  @override
  bool get isSupported => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => const [];

  @override
  Stream<StorePurchaseEvent> get purchases => const Stream.empty();

  @override
  Future<List<StorePurchaseEvent>> currentPurchases() async => const [];

  @override
  Future<void> openPaymentPage(Uri url) async => opened.add(url);
}

class _AuthedAuthBloc extends AuthBloc {
  _AuthedAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

/// Подпись кнопки оплаты рублями — суммы форматируются по локали (с
/// неразрывным пробелом), поэтому строка собирается тем же помощником.
String payButton(int rub) => 'Оплатить российской картой — ${rubLabel(rub)}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SubscriptionBloc.lavaPollInterval = Duration.zero;
    SubscriptionBloc.lavaPollAttempts = 3;
  });

  tearDown(getIt.reset);

  Widget wrap({
    required _StubRepository repository,
    _WebStore? store,
    Widget home = const TariffsPage(),
  }) {
    getIt.registerFactory<SubscriptionBloc>(
      () => SubscriptionBloc(repository, store ?? _WebStore()),
    );
    final storage = TokenStorage();
    final client = GraphqlClient(storage);
    final authRepository = AuthRepository(client, storage, AnalyticsService());
    final subscriptions = GraphqlSubscriptionClient(client, storage);
    final auth = _AuthedAuthBloc(authRepository, subscriptions);
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
        builder: (context) {
          Intl.defaultLocale = context.locale.toLanguageTag();
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
                    '/tariffs': (_) => const MaterialPage(
                      child: Scaffold(body: Text('витрина тарифов')),
                    ),
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

  testWidgets('в вебе кнопка оплаты рублями создаёт счёт и уводит на lava.top', (
    tester,
  ) async {
    wide(tester);
    final repository = _StubRepository();
    final store = _WebStore();

    await tester.pumpWidget(wrap(repository: repository, store: store));
    await tester.pumpAndSettle();

    // Открыт рекомендованный срок — три месяца — с ценой в рублях на кнопке;
    // крупная цифра карточки остаётся справочной, в динарах.
    expect(find.text(payButton(2390)), findsOneWidget);
    expect(find.text(priceLabel(2990)), findsOneWidget);
    // Карточка наверху говорит, что из России можно платить здесь.
    expect(find.textContaining('lava.top'), findsWidgets);

    await tester.tap(find.text(payButton(2390)));
    await tester.pump();
    // Пока счёт создаётся и вкладка уходит, кнопка заперта и говорит об этом
    // — и остаётся такой: вкладка сейчас уйдёт на lava.top, поэтому «устаканиться»
    // странице не положено.
    expect(find.text('Обрабатываем платёж…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Обрабатываем платёж…'), findsOneWidget);

    expect(repository.created.single.$1, 'premium_3m');
    expect(
      store.opened.single.toString(),
      'https://app.lava.top/pay/premium_3m',
    );
  });

  testWidgets('отказ бэкенда «подписка ещё действует» назван с датой', (
    tester,
  ) async {
    wide(tester);
    final repository = _StubRepository()
      ..createError = GraphqlException(
        'a subscription is still running',
        code: lavaSubscriptionActiveCode,
      );

    await tester.pumpWidget(wrap(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text(payButton(2390)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Подписка действует до'), findsOneWidget);
    // Кнопка отперта снова: человек может попробовать позже.
    expect(find.text(payButton(2390)), findsOneWidget);
  });

  testWidgets('действующая подписка lava.top: управление на своём тарифе, '
      'остальные заперты до конца периода', (tester) async {
    wide(tester);
    final repository = _StubRepository(
      status: _lavaStatus(cancelled: false),
      purchases: [_lavaPurchase(autoRenewing: true)],
    );

    await tester.pumpWidget(wrap(repository: repository));
    await tester.pumpAndSettle();

    // Открыт действующий тариф — месяц — с датой списания и управлением.
    expect(find.textContaining('Следующее списание'), findsOneWidget);
    expect(find.text('Управление подпиской'), findsOneWidget);
    expect(find.textContaining('Оплатить российской картой'), findsNothing);

    // На другом сроке вместо кнопки — «действует до …, новую после».
    await tester.tap(find.text('12 месяцев'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Новую подписку или пропуск можно оформить'),
      findsOneWidget,
    );
    expect(find.textContaining('Оплатить российской картой'), findsNothing);
  });

  testWidgets('лист управления: отмена с подтверждением, доступ до даты', (
    tester,
  ) async {
    wide(tester);
    final repository = _StubRepository(
      status: _lavaStatus(cancelled: false),
      purchases: [_lavaPurchase(autoRenewing: true)],
    );

    await tester.pumpWidget(wrap(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Управление подпиской'));
    await tester.pumpAndSettle();
    expect(find.text('Подписка Premium · российская карта'), findsOneWidget);
    expect(find.text('Сумма: ${rubLabel(1190)} в месяц'), findsOneWidget);

    await tester.tap(find.byKey(lavaCancelButtonKey));
    await tester.pumpAndSettle();
    // Подтверждение называет, до какого числа доступ сохранится.
    expect(find.text('Отменить подписку?'), findsOneWidget);
    expect(find.textContaining('Доступ сохранится до'), findsOneWidget);
    // Передумать можно.
    await tester.tap(find.text('Оставить'));
    await tester.pumpAndSettle();
    expect(repository.cancels, 0);

    await tester.tap(find.byKey(lavaCancelButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Отменить подписку'));
    await tester.pumpAndSettle();

    expect(repository.cancels, 1);
    // Лист закрылся, витрина говорит, что подписка отменена и до когда.
    expect(find.byKey(lavaCancelButtonKey), findsNothing);
    expect(find.textContaining('Подписка отменена'), findsWidgets);
    expect(find.textContaining('Следующее списание'), findsNothing);
  });

  testWidgets(
    'отменённая подписка в разделе «Подписка»: до даты, без списаний',
    (tester) async {
      final repository = _StubRepository(
        status: _lavaStatus(cancelled: true),
        purchases: [_lavaPurchase(autoRenewing: false)],
      );

      await tester.pumpWidget(
        wrap(repository: repository, home: const SubscriptionPage()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Подписка отменена'), findsOneWidget);
      expect(find.text('Управление подпиской'), findsOneWidget);

      await tester.tap(find.text('Управление подпиской'));
      await tester.pumpAndSettle();
      expect(
        find.text('Доступ действует до ${formatDate(_endsAt)}'),
        findsOneWidget,
      );
      expect(find.byKey(lavaCancelButtonKey), findsNothing);
    },
  );

  testWidgets('страница возврата ждёт оплату и уходит на экран подписки', (
    tester,
  ) async {
    final repository = _StubRepository()
      ..pollAnswers = const [LavaInvoiceStatus.pending, LavaInvoiceStatus.paid];
    // Между опросами — пауза, чтобы увидеть кадр ожидания.
    SubscriptionBloc.lavaPollInterval = const Duration(milliseconds: 100);

    await tester.pumpWidget(
      wrap(
        repository: repository,
        home: const LavaReturnPage(
          invoiceId: 'contract-new',
          status: 'success',
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Обрабатываем платёж'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(repository.polls, 2);
    expect(find.text('экран подписки'), findsOneWidget);
  });

  testWidgets('страница возврата: неоплаченный счёт — ошибка и путь назад', (
    tester,
  ) async {
    final repository = _StubRepository()
      ..pollAnswers = const [LavaInvoiceStatus.failed];

    await tester.pumpWidget(
      wrap(
        repository: repository,
        home: const LavaReturnPage(invoiceId: 'contract-new', status: 'failed'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Оплата не прошла'), findsOneWidget);
    await tester.tap(find.text('К тарифам'));
    await tester.pumpAndSettle();
    expect(find.text('витрина тарифов'), findsOneWidget);
  });

  testWidgets('страница возврата: без подтверждения — «проверить ещё раз»', (
    tester,
  ) async {
    final repository = _StubRepository()
      ..pollAnswers = const [LavaInvoiceStatus.pending];

    await tester.pumpWidget(
      wrap(
        repository: repository,
        home: const LavaReturnPage(invoiceId: 'contract-new'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.polls, 3);
    expect(
      find.textContaining('Подтверждение оплаты пока не пришло'),
      findsOneWidget,
    );
    repository.pollAnswers = const [LavaInvoiceStatus.paid];
    await tester.tap(find.text('Проверить ещё раз'));
    await tester.pumpAndSettle();
    expect(find.text('экран подписки'), findsOneWidget);
  });
}
