import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/billing_admin/data/billing_admin_repository.dart';
import 'package:saobracaj/billing_admin/models/billing_admin_models.dart';
import 'package:saobracaj/billing_admin/presentation/billing_admin_page.dart';
import 'package:saobracaj/billing_admin/state_management/billing_admin_bloc.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Репозиторий-заглушка: один ожидающий заказ, незаполненные реквизиты,
/// запоминает вызовы мутаций.
class _FakeRepo implements BillingAdminRepository {
  final calls = <String>[];
  bool payeeConfigured = false;

  Order _order() => Order.fromJson({
    'id': 'o1',
    'userId': 'u1',
    'userEmail': 'buyer@example.com',
    'sku': 'basic_12m',
    'tariffKind': 'BASIC',
    'months': 12,
    'amountRsd': 3490,
    'status': 'PENDING',
    'referenceDisplay': '82-00001234',
    'createdAt': '2026-08-16T10:00:00Z',
    'paymentDueAt': '2026-08-30T10:00:00Z',
    'payment': null,
  });

  @override
  Future<OrdersPage> orders({
    OrderStatus? status,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    calls.add('orders:${status?.name}:$search');
    return OrdersPage(items: [_order()], total: 1);
  }

  @override
  Future<BillingUser?> user(String email) async {
    calls.add('user:$email');
    if (email != 'buyer@example.com') return null;
    return BillingUser(
      userId: 'u1',
      email: email,
      subscription: const SubscriptionStatus(active: false),
      periods: const [],
      orders: [_order()],
    );
  }

  @override
  Future<List<BillingAuditEntry>> auditLog({int limit = 100}) async => [
    BillingAuditEntry(
      id: 'a1',
      action: 'order_created',
      createdAt: DateTime(2026, 8, 16),
      actorEmail: 'buyer@example.com',
      details: '{"sku":"basic_12m"}',
    ),
  ];

  @override
  Future<List<AdminTariff>> allTariffs() async => const [
    AdminTariff(
      sku: 'basic_1m',
      kind: TariffKind.basic,
      months: 1,
      priceRsd: 990,
      active: true,
    ),
  ];

  @override
  Future<Payee> payee() async => Payee(
    accountNumber: payeeConfigured ? '265000000012345678' : '',
    accountDisplay: payeeConfigured ? '265-0000000123456-78' : '',
    name: payeeConfigured ? 'Test PR' : '',
    paymentCode: '289',
    purpose: 'Saobraćaj pretplata',
    configured: payeeConfigured,
  );

  @override
  Future<Order> confirmOrder(String id) async {
    calls.add('confirm:$id');
    return _order();
  }

  @override
  Future<Order> cancelOrder(String id, {String? reason}) async {
    calls.add('cancel:$id:$reason');
    return _order();
  }

  @override
  Future<void> grantSubscription({
    required String userId,
    required TariffKind kind,
    required int months,
    String? note,
  }) async => calls.add('grant:$userId:${kind.name}:$months');

  @override
  Future<void> extendSubscription({
    required String userId,
    required int months,
    String? note,
  }) async => calls.add('extend:$userId:$months');

  @override
  Future<void> revokeSubscription({
    required String userId,
    String? note,
  }) async => calls.add('revoke:$userId');

  @override
  Future<AdminTariff> updateTariff(
    String sku, {
    int? priceRsd,
    bool? active,
  }) async {
    calls.add('tariff:$sku:$priceRsd:$active');
    return AdminTariff(
      sku: sku,
      kind: TariffKind.basic,
      months: 1,
      priceRsd: priceRsd ?? 990,
      active: active ?? true,
    );
  }

  final promos = <AdminPromoCode>[
    AdminPromoCode(
      code: 'ABCD2345',
      discountPercent: 25,
      sku: null,
      validUntil: DateTime(2026, 12, 31),
      createdAt: DateTime(2026, 8, 16),
      status: PromoCodeStatus.available,
    ),
    AdminPromoCode(
      code: 'USED2345',
      discountPercent: 100,
      sku: 'basic_1m',
      validUntil: DateTime(2026, 12, 31),
      createdAt: DateTime(2026, 8, 15),
      status: PromoCodeStatus.used,
      usedByEmail: 'buyer@example.com',
    ),
  ];

  @override
  Future<PromoCodesPage> promoCodes({int limit = 100, int offset = 0}) async {
    calls.add('promos');
    return PromoCodesPage(items: promos, total: promos.length);
  }

  @override
  Future<List<AdminPromoCode>> generatePromoCodes({
    required int count,
    required int discountPercent,
    required DateTime validUntil,
    String? sku,
    String? note,
  }) async {
    calls.add('generate:$count:$discountPercent:$sku:$note');
    return [
      for (var i = 0; i < count; i++)
        AdminPromoCode(
          code: 'NEW${i}CODE',
          discountPercent: discountPercent,
          sku: sku,
          validUntil: validUntil,
          note: note,
          createdAt: DateTime(2026, 8, 26),
          status: PromoCodeStatus.available,
        ),
    ];
  }

  @override
  Future<bool> deletePromoCode(String code) async {
    calls.add('deletePromo:$code');
    return code == 'ABCD2345';
  }

  @override
  Future<Payee> updatePayee({
    required String accountNumber,
    required String name,
    String? address,
    String? paymentCode,
    String? purpose,
  }) async {
    calls.add('payee:$accountNumber:$name');
    payeeConfigured = true;
    return payee();
  }
}

Future<_FakeRepo> _pump(WidgetTester tester) async {
  final repo = _FakeRepo();
  if (getIt.isRegistered<BillingAdminBloc>()) {
    getIt.unregister<BillingAdminBloc>();
  }
  getIt.registerFactory<BillingAdminBloc>(() => BillingAdminBloc(repo));
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: const Locale('ru'),
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const BillingAdminPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('стол открывается на заказах и предупреждает о реквизитах', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await _pump(tester);
    expect(find.text('buyer@example.com'), findsOneWidget);
    expect(find.textContaining('82-00001234'), findsWidgets);
    expect(
      find.textContaining('Реквизиты получателя не заполнены'),
      findsOneWidget,
    );
    expect(repo.calls, contains('orders:null:'));

    // Раскрываем заказ и подтверждаем оплату.
    await tester.tap(find.text('buyer@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Оплачен'));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердить оплату?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Оплачен').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('confirm:o1'));
  });

  testWidgets('вкладки пользователя, журнала, тарифов и реквизитов рисуются', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Пользователь'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'buyer@example.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('user:buyer@example.com'));
    expect(find.text('Активной подписки нет.'), findsOneWidget);
    expect(find.text('Выдать'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Журнал'));
    await tester.pumpAndSettle();
    expect(find.textContaining('order_created'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Тарифы'));
    await tester.pumpAndSettle();
    expect(find.text('basic_1m'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Реквизиты'));
    await tester.pumpAndSettle();
    expect(find.text('Получатель платежей'), findsOneWidget);
    // Кнопка сохранения выключена, пока счёт и получатель пусты.
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сохранить'),
    );
    expect(save.onPressed, isNull);
    await tester.enterText(find.byType(TextFormField).at(0), '265-1234567-89');
    await tester.enterText(find.byType(TextFormField).at(1), 'Test PR');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('payee:265-1234567-89:Test PR'));
    expect(find.textContaining('Реквизиты заполнены'), findsOneWidget);
  });

  testWidgets('вкладка промокодов: список, генерация и удаление', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Промокоды'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('promos'));
    expect(find.text('ABCD2345'), findsOneWidget);
    expect(find.text('USED2345'), findsOneWidget);
    // У использованного кода нет кнопки удаления, у свободного — есть.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // Кнопка генерации выключена, пока не выбрана дата окончания.
    final generate = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сгенерировать'),
    );
    expect(generate.onPressed, isNull);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Действует до…'));
    await tester.pumpAndSettle();
    // Кнопка подтверждения даты — через локализацию, а не литерал «OK».
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(BillingAdminPage)),
    );
    await tester.tap(find.text(localizations.okButtonLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Сгенерировать'));
    await tester.pumpAndSettle();
    expect(
      repo.calls.where((c) => c.startsWith('generate:10:10:null')),
      hasLength(1),
    );
    // Пачка новых кодов показана для копирования.
    expect(find.text('Новые коды'), findsOneWidget);
    expect(find.textContaining('NEW0CODE'), findsWidgets);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('deletePromo:ABCD2345'));
  });

  testWidgets('на телефоне заказы и реквизиты не переполняются', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    await tester.tap(find.text('buyer@example.com'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Оплачен'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Пользователь'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'buyer@example.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Выдать'), findsOneWidget);
    // Пятый чип на телефоне за краем экрана — доскроллить полосу вкладок.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Реквизиты'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Реквизиты'));
    await tester.pumpAndSettle();
    expect(find.text('Получатель платежей'), findsOneWidget);
  });
}
