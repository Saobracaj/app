import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/subscription/data/store_purchase_service.dart';
import 'package:saobracaj/subscription/data/subscription_repository.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/state_management/subscription_bloc.dart';
import 'package:saobracaj/subscription/state_management/subscription_events.dart';
import 'package:saobracaj/subscription/state_management/subscription_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Что Bloc подписки делает с транзакцией стора, когда бэкенд отказал в чеке.
///
/// Окончательный отказ (`purchase_rejected`: чужой живой аккаунт, возврат,
/// неизвестный товар) — транзакцию завершить, иначе StoreKit перевыдаёт её
/// при каждом запуске и не даёт купить тот же товар. Сетевая или серверная
/// ошибка — оставить в очереди, чтобы попробовать при следующем запуске.
/// Ошибка плагина «транзакция уже в очереди» — не «магазин недоступен», а
/// автоматический restore.

Tariff _tariff(String sku, int months) => Tariff(
  sku: sku,
  months: months,
  priceRsd: 1490 * months,
  appleProductId: 'at.gleb.saobracaj.$sku',
  googleProductId: sku,
  autoRenewing: months == 1,
);

class _StubRepository extends SubscriptionRepository {
  _StubRepository()
    : super(
        GraphqlClient(TokenStorage()),
        FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  /// Чем бэкенд отвечает на чек вместо права.
  GraphqlException? redeemError;
  final redeemed = <String>[];

  @override
  Future<List<Tariff>> tariffs() async => [
    _tariff('premium_1m', 1),
    _tariff('premium_3m', 3),
  ];

  @override
  Future<SubscriptionStatus> mySubscription() async => SubscriptionStatus.none;

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
    redeemed.add(receipt);
    if (redeemError != null) throw redeemError!;
    return const SubscriptionStatus(active: true);
  }

  @override
  Future<void> refreshGrants() async {}
}

class _FakeStore extends StorePurchaseService {
  @override
  StorePlatform? get platform => StorePlatform.apple;

  @override
  bool get isSupported => true;

  /// Чем падает `buy`, если падает.
  Object? buyError;
  final bought = <String>[];
  var restoreCalls = 0;
  final completed = <StorePurchaseEvent>[];
  final _events = StreamController<StorePurchaseEvent>.broadcast();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final id in ids)
      StoreProduct(id: id, price: '€1', rawPrice: 1, currencyCode: 'EUR'),
  ];

  @override
  Stream<StorePurchaseEvent> get purchases => _events.stream;

  @override
  Future<void> buy({
    required String productId,
    required bool autoRenewing,
  }) async {
    bought.add(productId);
    if (buyError != null) throw buyError!;
  }

  @override
  Future<void> restore() async => restoreCalls++;

  @override
  Future<void> complete(StorePurchaseEvent event) async => completed.add(event);

  void emit(StorePurchaseEvent event) => _events.add(event);
}

StorePurchaseEvent _receipt() => StorePurchaseEvent(
  productId: 'at.gleb.saobracaj.premium_1m',
  receipt: 'tx-1',
  outcome: StorePurchaseOutcome.restored,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  late _StubRepository repo;
  late _FakeStore store;
  late SubscriptionBloc bloc;
  late List<SubscriptionState> states;

  setUp(() async {
    repo = _StubRepository();
    store = _FakeStore();
    bloc = SubscriptionBloc(repo, store);
    states = [];
    bloc.stream.listen(states.add);
    // Каталог загружен — без него ни купить, ни сопоставить чек с тарифом.
    await bloc.stream.firstWhere((s) => s.tariffs.isNotEmpty && !s.inProgress);
  });

  tearDown(() => bloc.close());

  /// Дождаться, пока Bloc закончит с чеком.
  Future<SubscriptionState> settled() => bloc.stream
      .firstWhere((s) => !s.redeeming && s.purchasingSku == null)
      .timeout(const Duration(seconds: 5));

  test('окончательный отказ бэкенда завершает транзакцию стора', () async {
    repo.redeemError = GraphqlException(
      'this purchase is already tied to another account',
      code: purchaseRejectedCode,
    );
    final receipt = _receipt();
    final done = settled();
    store.emit(receipt);
    final state = await done;

    expect(repo.redeemed, ['tx-1']);
    expect(
      state.errorMessage,
      'this purchase is already tied to another account',
    );
    // Дать `complete` (после emit) выполниться.
    await Future<void>.delayed(Duration.zero);
    expect(store.completed, [receipt]);
  });

  test('сетевая ошибка оставляет транзакцию в очереди', () async {
    repo.redeemError = GraphqlException('no route', network: true);
    final done = settled();
    store.emit(_receipt());
    final state = await done;

    expect(state.errorMessage, isNotNull);
    await Future<void>.delayed(Duration.zero);
    expect(store.completed, isEmpty);
  });

  test(
    'серверная ошибка (не окончательный отказ) тоже оставляет транзакцию',
    () async {
      repo.redeemError = GraphqlException(
        'App Store purchases are not configured on this server',
        code: 'validation_error',
      );
      final done = settled();
      store.emit(_receipt());
      final state = await done;

      expect(
        state.errorMessage,
        'App Store purchases are not configured on this server',
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.completed, isEmpty);
    },
  );

  test('принятый чек завершается стору после записи права', () async {
    final receipt = _receipt();
    final done = settled();
    store.emit(receipt);
    final state = await done;

    expect(state.errorMessage, isNull);
    expect(state.subscription.active, isTrue);
    expect(store.completed, [receipt]);
  });

  test(
    '«транзакция уже в очереди» → не «магазин недоступен», а restore',
    () async {
      store.buyError = PlatformException(
        code: storeKitDuplicateProductCode,
        message:
            'There is a pending transaction for the same product identifier.',
      );
      bloc.add(PurchaseRequested('premium_1m'));
      await bloc.stream
          .firstWhere(
            (s) =>
                !s.restoring &&
                s.purchasingSku == null &&
                store.restoreCalls > 0,
          )
          .timeout(const Duration(seconds: 5));

      expect(store.bought, ['at.gleb.saobracaj.premium_1m']);
      expect(store.restoreCalls, 1);
      expect(
        states.map((s) => s.infoMessage),
        contains(LocaleKeys.subscription_purchaseAlreadyInStore.tr()),
      );
      expect(
        states.map((s) => s.errorMessage),
        isNot(contains(LocaleKeys.subscription_storeUnavailable.tr())),
      );
    },
  );

  test(
    'любая другая ошибка покупки — «магазин недоступен» без restore',
    () async {
      store.buyError = PlatformException(code: 'storekit_no_response');
      bloc.add(PurchaseRequested('premium_1m'));
      final state = await bloc.stream
          .firstWhere((s) => s.errorMessage != null)
          .timeout(const Duration(seconds: 5));

      expect(state.errorMessage, LocaleKeys.subscription_storeUnavailable.tr());
      expect(store.restoreCalls, 0);
    },
  );
}
