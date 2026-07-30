import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/navigation_bridge_handler.dart';
import 'package:granite_climbing_app/features/navigation/native_navigation_service.dart';

import 'ignored_bridge_sender.dart';

void main() {
  test('opens allowed external URLs through the native navigation service',
      () async {
    final service = RecordingNativeNavigationService();
    final handler = NavigationBridgeHandler(navigationService: service);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'navigation.open.external.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'url': 'https://granite.kr/me',
        },
      ),
      const IgnoredBridgeSender(),
    );

    expect(service.externalUrls, [Uri.parse('https://granite.kr/me')]);
  });

  test('rejects external URLs outside the allowlist', () async {
    final service = RecordingNativeNavigationService();
    final handler = NavigationBridgeHandler(navigationService: service);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'navigation.open.external.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'url': 'javascript:alert(1)',
        },
      ),
      const IgnoredBridgeSender(),
    );

    expect(service.externalUrls, isEmpty);
  });

  test('opens the fixed Smart Store URL through the native navigation service',
      () async {
    final service = RecordingNativeNavigationService();
    final handler = NavigationBridgeHandler(navigationService: service);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'navigation.open.external.requested',
        direction: BridgeDirection.webToNative,
        payload: {'url': 'https://m.smartstore.naver.com/granite_kr'},
      ),
      const IgnoredBridgeSender(),
    );

    expect(service.externalUrls,
        [Uri.parse('https://m.smartstore.naver.com/granite_kr')]);
  });
}

class RecordingNativeNavigationService implements NativeNavigationService {
  final List<Uri> externalUrls = [];

  @override
  Future<void> openExternal(Uri url) async {
    externalUrls.add(url);
  }
}
