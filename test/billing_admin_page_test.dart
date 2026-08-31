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

/// Репозиторий-заглушка: одна покупка в Google Play, запоминает вызовы.
class _FakeRepo implements BillingAdminRepository {
  final calls = <String>[];

  StorePurchase _purchase() => StorePurchase.fromJson({
    'id': 'p1',
    'userId': 'u1',
    'userEmail': 'buyer@example.com',
    'platform': 'GOOGLE',
    'sku': 'basic_12m',
    'tariffKind': 'BASIC',
    'months': 12,
    'productId': 'basic_12m',
    'transactionId': 'GPA.3311-1111-2222-33333',
    'autoRenewing': false,
    'status': 'ACTIVE',
    'purchasedAt': '2026-08-16T10:00:00Z',
    'expiresAt': null,
  });

  @override
  Future<StorePurchasesPage> purchases({
    StorePlatform? platform,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    calls.add('purchases:${platform?.name}:$search');
    return StorePurchasesPage(items: [_purchase()], total: 1);
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
      purchases: [_purchase()],
    );
  }

  @override
  Future<List<BillingAuditEntry>> auditLog({int limit = 100}) async => [
    BillingAuditEntry(
      id: 'a1',
      action: 'store_purchase_redeemed',
      createdAt: DateTime(2026, 8, 16),
      actorEmail: null,
      details: '{"sku":"basic_12m"}',
    ),
  ];

  @override
  Future<List<AdminTariff>> allTariffs() async => const [
    AdminTariff(
      sku: 'basic_1m',
      kind: TariffKind.basic,
      months: 1,
      priceRsd: 1190,
      active: true,
      appleProductId: 'at.gleb.saobracaj.basic_1m',
      googleProductId: 'basic_1m',
      autoRenewing: true,
    ),
  ];

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
    String? appleProductId,
    String? googleProductId,
  }) async {
    calls.add('tariff:$sku:$priceRsd:$active');
    return AdminTariff(
      sku: sku,
      kind: TariffKind.basic,
      months: 1,
      priceRsd: priceRsd ?? 1190,
      active: active ?? true,
      appleProductId: appleProductId ?? 'at.gleb.saobracaj.basic_1m',
      googleProductId: googleProductId ?? 'basic_1m',
      autoRenewing: true,
    );
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
  testWidgets('стол открывается на покупках и показывает платёж целиком', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await _pump(tester);

    expect(find.text('buyer@example.com'), findsOneWidget);
    // Идентификатор платежа — то, по чему покупку ищут в консоли стора.
    expect(find.text('GPA.3311-1111-2222-33333'), findsOneWidget);
    expect(find.textContaining('Google Play'), findsWidgets);
    expect(repo.calls, contains('purchases:null:'));
    // Подтверждать оплату больше нечего: этих кнопок на столе нет.
    expect(find.text('Оплачен'), findsNothing);
    expect(find.text('Отменить'), findsNothing);
  });

  testWidgets('вкладки пользователя, журнала и тарифов рисуются', (
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
    // Ручная выдача осталась — ею чинят возвраты и апгрейды.
    expect(find.text('Выдать'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Журнал'));
    await tester.pumpAndSettle();
    expect(find.textContaining('store_purchase_redeemed'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Тарифы'));
    await tester.pumpAndSettle();
    expect(find.text('basic_1m'), findsOneWidget);
    // Идентификаторы товаров видны: расхождение с консолью выглядит как
    // «кнопка купить ничего не делает», и найти его надо здесь.
    expect(
      find.textContaining('App Store: at.gleb.saobracaj.basic_1m'),
      findsOneWidget,
    );
  });

  testWidgets('на телефоне покупки и карточка пользователя не переполняются', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);

    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Пользователь'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'buyer@example.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Выдать'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
