import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/store_links.dart';
import 'package:saobracaj/subscription/data/store_purchase_service.dart';

/// «Управлять подпиской»: на iOS — нативная шторка StoreKit сразу на нашей
/// группе подписок, везде остальном (и когда шторка не открылась) — ссылка
/// стора, которую прислал бэкенд.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sheet = MethodChannel('at.gleb.saobracaj/subscriptions');
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  const manageUrl = 'https://apps.apple.com/account/subscriptions';

  late List<MethodCall> sheetCalls;
  late List<String> launched;
  Object? sheetError;

  setUp(() {
    sheetCalls = [];
    launched = [];
    sheetError = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sheet, (call) async {
      sheetCalls.add(call);
      if (sheetError != null) throw sheetError!;
      return null;
    });
    messenger.setMockMethodCallHandler(launcher, (call) async {
      launched.add((call.arguments as Map)['url'] as String);
      return true;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sheet, null);
    messenger.setMockMethodCallHandler(launcher, null);
  });

  test('на iOS открывает шторку StoreKit с группой подписок', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await StorePurchaseService().openSubscriptionManagement(
      manageUrl: manageUrl,
    );

    expect(sheetCalls.single.method, 'showManageSubscriptions');
    expect(sheetCalls.single.arguments, {
      'subscriptionGroupId': appStoreSubscriptionGroupId,
    });
    expect(launched, isEmpty);
  });

  test('если шторка не открылась — запасная ссылка стора', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    sheetError = PlatformException(code: 'storekit', message: 'no scene');

    await StorePurchaseService().openSubscriptionManagement(
      manageUrl: manageUrl,
    );

    expect(sheetCalls, hasLength(1));
    expect(launched, [manageUrl]);
  });

  test('на Android — только ссылка Google Play', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const playUrl =
        'https://play.google.com/store/account/subscriptions?sku=premium_1m&package=at.gleb.saobracaj';

    await StorePurchaseService().openSubscriptionManagement(manageUrl: playUrl);

    expect(sheetCalls, isEmpty);
    expect(launched, [playUrl]);
  });

  test('без ссылки и вне сторов ничего не делает', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await StorePurchaseService().openSubscriptionManagement(manageUrl: null);

    expect(sheetCalls, isEmpty);
    expect(launched, isEmpty);
  });
}
