import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var pendingStagingTap: [String: Any]?
  private var lastStagingTapId: String?

  func receiveStagingNotificationTap(_ userInfo: [AnyHashable: Any]) {
    guard Bundle.main.bundleIdentifier == "com.andalus.aqar.staging",
          let messageId = userInfo["gcm.message_id"] as? String else { return }
    guard lastStagingTapId != messageId else { return }
    lastStagingTapId = messageId
    var payload: [String: Any] = [:]
    for (key, value) in userInfo {
      guard let key = key as? String,
            key != "aps", !key.hasPrefix("google."), !key.hasPrefix("gcm.") else { continue }
      payload[key] = value
    }
    pendingStagingTap = payload
    // Dart drains the pending value. If its handler isn't ready, startup drains it.
    pushChannel?.invokeMethod("notificationTapAvailable", arguments: nil)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    receiveStagingNotificationTap(response.notification.request.content.userInfo)
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // UIScene creates the Flutter engine after this launch callback. Install
    // the lifecycle forwarding delegate early so system notification taps reach
    // the registered messaging plugin. Limit this migration to the test bundle.
    if Bundle.main.bundleIdentifier == "com.andalus.aqar.staging" {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "aqar/push_privacy",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pushChannel = channel
    if Bundle.main.bundleIdentifier == "com.andalus.aqar.staging" {
      UNUserNotificationCenter.current().delegate = self
    }
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getPendingNotificationTap",
         Bundle.main.bundleIdentifier == "com.andalus.aqar.staging" {
        let payload = self?.pendingStagingTap
        self?.pendingStagingTap = nil
        result(payload)
        return
      }
      guard call.method == "clearDeliveredNotifications" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let center = UNUserNotificationCenter.current()
      center.removeAllDeliveredNotifications()
      center.removeAllPendingNotificationRequests()
      self?.pendingStagingTap = nil
      result(nil)
    }
  }
}
