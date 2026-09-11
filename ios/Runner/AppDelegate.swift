import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    SubscriptionsChannel.register(with: engineBridge.pluginRegistry)
  }
}

/// Канал `at.gleb.saobracaj/subscriptions` — то, чего нет в плагине
/// `in_app_purchase`: шторка StoreKit «управление подписками» внутри
/// приложения и тихий список действующих покупок аккаунта App Store.
/// Dart-сторона — `StorePurchaseService.openSubscriptionManagement` и
/// `StorePurchaseService.currentPurchases`.
///
/// `currentEntitlements` — то, чем плагин (StoreKit 1) не располагает: его
/// `restorePurchases` может показать окно входа в App Store, а StoreKit 2
/// отдаёт действующие покупки без единого диалога. Витрина спрашивает их
/// перед продажей, чтобы не продать второй пропуск тому, за кого стор уже
/// списывает деньги. Каждая запись — `productId`, `transactionId`,
/// `autoRenewable`.
///
/// С iOS 17 шторка умеет открываться сразу на группе подписок, то есть на
/// конкретной подписке пользователя, а не на общем списке аккаунта. Группу
/// берём из текущей покупки в StoreKit; если её там нет — из аргумента
/// `subscriptionGroupId` (константа в `lib/core/store_links.dart`); без
/// обеих (или на iOS 15–16) открывается общий список подписок приложения.
enum SubscriptionsChannel {
  static let name = "at.gleb.saobracaj/subscriptions"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "SubscriptionsChannel") else { return }
    let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "showManageSubscriptions":
        let args = call.arguments as? [String: Any]
        let fallback = args?["subscriptionGroupId"] as? String
        showManageSubscriptions(fallbackGroupID: fallback, result: result)
      case "currentEntitlements":
        currentEntitlements(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func showManageSubscriptions(
    fallbackGroupID: String?, result: @escaping FlutterResult
  ) {
    Task { @MainActor in
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
        ?? scenes.first
      else {
        result(FlutterError(code: "no_scene", message: "no window scene", details: nil))
        return
      }
      do {
        if #available(iOS 17.0, *),
          let group = await ownedSubscriptionGroupID() ?? nonEmpty(fallbackGroupID)
        {
          try await AppStore.showManageSubscriptions(in: scene, subscriptionGroupID: group)
        } else {
          try await AppStore.showManageSubscriptions(in: scene)
        }
        result(nil)
      } catch {
        result(FlutterError(code: "storekit", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// Действующие покупки аккаунта App Store — подписки и пропуска, срок
  /// которых ещё идёт. Только проверенные StoreKit транзакции: чек всё равно
  /// перепроверит бэкенд, но выдумку сюда не пропускаем.
  private static func currentEntitlements(result: @escaping FlutterResult) {
    Task {
      var entitlements: [[String: Any]] = []
      for await entitlement in StoreKit.Transaction.currentEntitlements {
        guard case .verified(let transaction) = entitlement else { continue }
        entitlements.append([
          "productId": transaction.productID,
          "transactionId": String(transaction.id),
          "autoRenewable": transaction.productType == .autoRenewable,
        ])
      }
      result(entitlements)
    }
  }

  /// Группа автопродлеваемой подписки, которой пользователь владеет сейчас.
  private static func ownedSubscriptionGroupID() async -> String? {
    for await entitlement in StoreKit.Transaction.currentEntitlements {
      if case .verified(let transaction) = entitlement,
        transaction.productType == .autoRenewable
      {
        return transaction.subscriptionGroupID
      }
    }
    return nil
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }
}
