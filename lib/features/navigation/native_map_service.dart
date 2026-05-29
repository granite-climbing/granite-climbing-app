import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart' as launcher;

enum NativeMapPlatform {
  ios,
  android,
  other,
}

class NativeMapLocation {
  const NativeMapLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

abstract interface class NativeMapLauncher {
  Future<bool> canLaunch(Uri url);

  Future<void> launch(Uri url);
}

class UrlLauncherNativeMapLauncher implements NativeMapLauncher {
  const UrlLauncherNativeMapLauncher();

  @override
  Future<bool> canLaunch(Uri url) {
    return launcher.canLaunchUrl(url);
  }

  @override
  Future<void> launch(Uri url) async {
    await launcher.launchUrl(
      url,
      mode: launcher.LaunchMode.externalApplication,
    );
  }
}

class NativeMapService {
  const NativeMapService({
    this.platform,
    this.launcher = const UrlLauncherNativeMapLauncher(),
  });

  final NativeMapPlatform? platform;
  final NativeMapLauncher launcher;

  Future<void> openPreferred(NativeMapLocation location) async {
    final kakaoMapUrl = _buildKakaoMapUrl(location);
    if (await _canLaunch(kakaoMapUrl)) {
      await launcher.launch(kakaoMapUrl);
      return;
    }

    await launcher.launch(_buildPlatformMapUrl(location));
  }

  NativeMapPlatform _currentPlatform() {
    if (Platform.isIOS) {
      return NativeMapPlatform.ios;
    }

    if (Platform.isAndroid) {
      return NativeMapPlatform.android;
    }

    return NativeMapPlatform.other;
  }

  Future<bool> _canLaunch(Uri url) async {
    try {
      return await launcher.canLaunch(url);
    } catch (_) {
      return false;
    }
  }

  Uri _buildKakaoMapUrl(NativeMapLocation location) {
    final coordinate = _coordinate(location);
    return Uri.parse('kakaomap://look?p=$coordinate');
  }

  Uri _buildPlatformMapUrl(NativeMapLocation location) {
    final targetPlatform = platform ?? _currentPlatform();

    switch (targetPlatform) {
      case NativeMapPlatform.android:
        return _buildAndroidMapUrl(location);
      case NativeMapPlatform.ios:
      case NativeMapPlatform.other:
        return _buildAppleMapsUrl(location);
    }
  }

  Uri _buildAppleMapsUrl(NativeMapLocation location) {
    final coordinate = _coordinate(location);
    return Uri.parse(
      'https://maps.apple.com/?ll=$coordinate&q=${Uri.encodeComponent(location.label)}',
    );
  }

  Uri _buildAndroidMapUrl(NativeMapLocation location) {
    return Uri.parse('geo:0,0?q=${_googleGeoQuery(location)}');
  }

  String _coordinate(NativeMapLocation location) {
    return '${location.latitude},${location.longitude}';
  }

  String _googleGeoQuery(NativeMapLocation location) {
    return Uri.encodeComponent('${_coordinate(location)}(${location.label})');
  }
}
