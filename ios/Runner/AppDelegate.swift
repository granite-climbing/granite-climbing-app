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
    registerNativeSocialLoginChannel(engineBridge.pluginRegistry)
  }

  private func registerNativeSocialLoginChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "NativeSocialLoginChannel") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.granite.climbing/native_social_login",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "loginWithNaver":
        result(
          FlutterError(
            code: "not_configured",
            message: "Naver native login is not configured.",
            details: nil
          )
        )
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
