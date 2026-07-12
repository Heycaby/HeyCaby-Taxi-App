import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self
    registerIncomingRideNotificationCategory()
    application.registerForRemoteNotifications()
    return ok
  }

  private func registerIncomingRideNotificationCategory() {
    let openAction = UNNotificationAction(
      identifier: "HEYCABY_OPEN_RIDE",
      title: "Open ride",
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: "HEYCABY_INCOMING_RIDE",
      actions: [openAction],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
