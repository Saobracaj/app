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

  /// Подписка появляется у аккаунта, как только бэкенд принял чек, — как на
  /// сервере, где принятый чек и есть право.
  @override
  Future<SubscriptionStatus> mySubscription() async => redeemed.isEmpty
      ? SubscriptionStatus.none
      : const SubscriptionStatus(active: true);

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

  /// Что стор называет действующими покупками аккаунта — то, с чем витрина
  /// сверяется перед продажей.
  var current = <StorePurchaseEvent>[];

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
  Future<void> buy({required String productId}) async {
    bought.add(productId);
    if (buyError != null) throw buyError!;
  }

  @override
  Future<void> restore() async => restoreCalls++;

  @override
  Future<List<StorePurchaseEvent>> currentPurchases() async => current;

  @override
  Future<void> complete(StorePurchaseEvent event) async => completed.add(event);

  void emit(StorePurchaseEvent event) => _events.add(event);
}

StorePurchaseEvent _receipt() => StorePurchaseEvent(
  productId: 'at.gleb.saobracaj.premium_1m',
  receipt: 'tx-1',
  outcome: StorePurchaseOutcome.restored,
);

/// Экран открыт и сверка со стором закончена.
bool ready(SubscriptionState s) =>
    s.tariffs.isNotEmpty && !s.inProgress && !s.syncingStore;

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
    // Каталог загружен — без него ни купить, ни сопоставить чек с тарифом, —
    // и сверка со стором (пустая) закончена.
    await bloc.stream.firstWhere(ready);
  });

  tearDown(() => bloc.close());

  group('сверка со стором перед продажей', syncTests);

  /// Дождаться, пока Bloc закончит с чеком.
  Future<SubscriptionState> settled() => bloc.stream
      .firstWhere(
        (s) => !s.redeeming && s.purchasingSku == null && !s.syncingStore,
      )
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

/// Сверка со стором перед продажей: у аккаунта стора может быть живая
/// подписка, о которой бэкенд не знает (оформлена с удалённого аккаунта —
/// удаление подписку в сторе не отменяет). Витрина тихо несёт её на бэкенд:
/// подписка удалённого аккаунта переезжает сюда, чужого живого — запирает
/// кнопки, а сбой сети ничего не меняет и ничего не показывает.
void syncTests() {
  late _StubRepository repo;
  late _FakeStore store;
  late SubscriptionBloc bloc;

  setUp(() {
    repo = _StubRepository();
    store = _FakeStore()..current = [_receipt()];
  });

  tearDown(() => bloc.close());

  Future<SubscriptionState> open() {
    bloc = SubscriptionBloc(repo, store);
    return bloc.stream.firstWhere(ready).timeout(const Duration(seconds: 5));
  }

  test('живая покупка стора переезжает на этот аккаунт до продажи', () async {
    final state = await open();

    expect(repo.redeemed, ['tx-1']);
    expect(state.subscription.active, isTrue);
    expect(state.storeSubscriptionElsewhere, isFalse);
    expect(state.canBuy, isFalse);
    expect(state.infoMessage, LocaleKeys.subscription_restoreFound.tr());
    expect(store.completed, [store.current.single]);
  });

  test('подписка другого живого аккаунта запирает витрину', () async {
    repo.redeemError = GraphqlException(
      'this purchase is already tied to another account',
      code: purchaseOwnedElsewhereCode,
    );
    final state = await open();

    expect(state.storeSubscriptionElsewhere, isTrue);
    expect(state.canBuy, isFalse);
    expect(state.subscription.active, isFalse);
    // Не ошибка — человек ничего не нажимал; объяснение даёт сама витрина.
    expect(state.errorMessage, isNull);
    // Транзакцию завершаем: повтор ничего не изменит.
    expect(store.completed, [store.current.single]);
  });

  test('другой окончательный отказ не запирает, но завершает', () async {
    repo.redeemError = GraphqlException(
      'this purchase was refunded',
      code: purchaseRejectedCode,
    );
    final state = await open();

    expect(state.storeSubscriptionElsewhere, isFalse);
    expect(state.canBuy, isTrue);
    expect(state.errorMessage, isNull);
    expect(store.completed, [store.current.single]);
  });

  test('сбой сети при сверке молчит и продажу не запирает', () async {
    repo.redeemError = GraphqlException('no route', network: true);
    final state = await open();

    expect(state.storeSubscriptionElsewhere, isFalse);
    expect(state.canBuy, isTrue);
    expect(state.errorMessage, isNull);
    expect(store.completed, isEmpty);
  });

  test('чужой чек из очереди стора тоже запирает витрину', () async {
    store.current = [];
    await open();
    repo.redeemError = GraphqlException(
      'this purchase is already tied to another account',
      code: purchaseOwnedElsewhereCode,
    );
    final receipt = _receipt();
    final done = bloc.stream
        .firstWhere((s) => s.storeSubscriptionElsewhere)
        .timeout(const Duration(seconds: 5));
    store.emit(receipt);
    final state = await done;

    expect(
      state.errorMessage,
      'this purchase is already tied to another account',
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.completed, [receipt]);
  });
}
