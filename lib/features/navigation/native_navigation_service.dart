import 'package:url_launcher/url_launcher.dart' as launcher;

abstract interface class NativeNavigationService {
  Future<void> openExternal(Uri url);
}

class DevNativeNavigationService implements NativeNavigationService {
  const DevNativeNavigationService();

  @override
  Future<void> openExternal(Uri url) async {
    await launcher.launchUrl(
      url,
      mode: launcher.LaunchMode.externalApplication,
    );
  }
}
