import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)

    guard let appDelegate = UIApplication.shared.delegate else {
      return
    }

    for context in URLContexts {
      guard
        let urlScheme = context.url.scheme,
        naverURLSchemes.contains(urlScheme)
      else {
        continue
      }

      _ = appDelegate.application?(
        UIApplication.shared,
        open: context.url,
        options: context.applicationOpenURLOptions
      )
    }
  }

  private var naverURLSchemes: Set<String> {
    guard
      let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
    else {
      return []
    }

    return Set(urlTypes.flatMap { urlType in
      (urlType["CFBundleURLSchemes"] as? [String] ?? []).filter { scheme in
        !scheme.hasPrefix("kakao") &&
          !scheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
    })
  }
}

private extension UIOpenURLContext {
  var applicationOpenURLOptions: [UIApplication.OpenURLOptionsKey: Any] {
    var options: [UIApplication.OpenURLOptionsKey: Any] = [
      .openInPlace: self.options.openInPlace,
    ]

    if let sourceApplication = self.options.sourceApplication {
      options[.sourceApplication] = sourceApplication
    }
    if let annotation = self.options.annotation {
      options[.annotation] = annotation
    }

    return options
  }
}