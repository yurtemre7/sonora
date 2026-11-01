import Flutter
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

    // iOS side of the channel Android serves in MainActivity.kt. Only the
    // methods iOS needs exist; other calls fail and Dart falls back.
    let channel = FlutterMethodChannel(
      name: "de.yurtemre.sonora/volume",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openUrl":
        let args = call.arguments as? [String: Any]
        guard let text = args?["url"] as? String, let url = URL(string: text) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      case "getPackageInfo":
        let info = Bundle.main.infoDictionary ?? [:]
        result([
          "appName": info["CFBundleDisplayName"] as? String ?? "Sonora",
          "packageName": Bundle.main.bundleIdentifier ?? "de.yurtemre.sonora",
          "version": info["CFBundleShortVersionString"] as? String ?? "",
          "buildNumber": info["CFBundleVersion"] as? String ?? "",
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
