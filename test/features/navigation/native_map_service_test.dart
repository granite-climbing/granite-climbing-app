import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/navigation/native_map_service.dart';

void main() {
  const location = NativeMapLocation(
    label: '수락산 주차장',
    latitude: 37.682312,
    longitude: 127.058412,
  );

  test('opens Kakao Map directly when it is installed', () async {
    final kakaoUrl = Uri.parse('kakaomap://look?p=37.682312,127.058412');
    final launcher = RecordingNativeMapLauncher(
      canLaunchResults: {
        kakaoUrl: true,
      },
    );
    final service = NativeMapService(
      platform: NativeMapPlatform.ios,
      launcher: launcher,
    );

    await service.openPreferred(location);

    expect(launcher.canLaunchUrls, [kakaoUrl]);
    expect(launcher.launchedUrls, [kakaoUrl]);
  });

  test('falls back to Apple Maps on iOS when Kakao Map is unavailable',
      () async {
    final launcher = RecordingNativeMapLauncher();
    final service = NativeMapService(
      platform: NativeMapPlatform.ios,
      launcher: launcher,
    );

    await service.openPreferred(location);

    expect(launcher.canLaunchUrls, [
      Uri.parse('kakaomap://look?p=37.682312,127.058412'),
    ]);
    expect(launcher.launchedUrls, [
      Uri.parse(
        'https://maps.apple.com/?ll=37.682312,127.058412&q=%EC%88%98%EB%9D%BD%EC%82%B0%20%EC%A3%BC%EC%B0%A8%EC%9E%A5',
      ),
    ]);
  });

  test('falls back to the Android map intent when Kakao Map is unavailable',
      () async {
    final launcher = RecordingNativeMapLauncher();
    final service = NativeMapService(
      platform: NativeMapPlatform.android,
      launcher: launcher,
    );

    await service.openPreferred(location);

    expect(launcher.canLaunchUrls, [
      Uri.parse('kakaomap://look?p=37.682312,127.058412'),
    ]);
    expect(launcher.launchedUrls, [
      Uri.parse(
        'geo:0,0?q=37.682312%2C127.058412(%EC%88%98%EB%9D%BD%EC%82%B0%20%EC%A3%BC%EC%B0%A8%EC%9E%A5)',
      ),
    ]);
  });
}

class RecordingNativeMapLauncher implements NativeMapLauncher {
  RecordingNativeMapLauncher({
    this.canLaunchResults = const <Uri, bool>{},
  });

  final Map<Uri, bool> canLaunchResults;
  final List<Uri> canLaunchUrls = [];
  final List<Uri> launchedUrls = [];

  @override
  Future<bool> canLaunch(Uri url) async {
    canLaunchUrls.add(url);
    return canLaunchResults[url] ?? false;
  }

  @override
  Future<void> launch(Uri url) async {
    launchedUrls.add(url);
  }
}
