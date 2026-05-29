import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/navigation_map_bridge_handler.dart';
import 'package:granite_climbing_app/features/navigation/native_map_service.dart';

import 'ignored_bridge_sender.dart';

void main() {
  test('opens the native map for a valid coordinate payload', () async {
    final requests = <NativeMapLocation>[];
    final handler = NavigationMapBridgeHandler(openMap: requests.add);

    const message = BridgeMessage(
      version: 1,
      type: 'navigation.map.open.requested',
      direction: BridgeDirection.webToNative,
      payload: {
        'label': '수락산 주차장',
        'latitude': 37.682312,
        'longitude': 127.058412,
      },
    );

    expect(handler.canHandle(message), isTrue);

    await handler.handle(message, const IgnoredBridgeSender());

    expect(requests.single.label, '수락산 주차장');
    expect(requests.single.latitude, 37.682312);
    expect(requests.single.longitude, 127.058412);
  });

  test('ignores invalid map payloads', () async {
    final requests = <NativeMapLocation>[];
    final handler = NavigationMapBridgeHandler(openMap: requests.add);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'navigation.map.open.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'label': '',
          'latitude': '37.682312',
          'longitude': 127.058412,
        },
      ),
      const IgnoredBridgeSender(),
    );

    expect(requests, isEmpty);
  });
}
