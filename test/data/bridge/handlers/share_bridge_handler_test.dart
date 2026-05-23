import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/share_bridge_handler.dart';
import 'package:granite_climbing_app/features/share/native_share_service.dart';

void main() {
  test('shares a route and responds with completion', () async {
    final service = RecordingNativeShareService(NativeShareResult.completed());
    final sender = RecordingBridgeSender();
    final handler = ShareBridgeHandler(shareService: service);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        id: 'share-1',
        type: 'share.route.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'routeId': 'route-sky-hook',
          'title': 'Sky Hook',
          'url': 'https://granite.kr/r/route-sky-hook',
        },
      ),
      sender,
    );

    expect(service.requests.single.routeId, 'route-sky-hook');
    expect(sender.messages.single.toJson(), {
      'version': 1,
      'id': 'share-1',
      'type': 'share.route.completed',
      'direction': 'native-to-web',
      'payload': {
        'ok': true,
      },
    });
  });

  test('responds with failure when native sharing is unavailable', () async {
    final service = RecordingNativeShareService(
      NativeShareResult.failed(
        code: 'native_share_unavailable',
        message: 'Native share is unavailable.',
      ),
    );
    final sender = RecordingBridgeSender();
    final handler = ShareBridgeHandler(shareService: service);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        id: 'share-1',
        type: 'share.route.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'routeId': 'route-sky-hook',
          'title': 'Sky Hook',
          'url': 'https://granite.kr/r/route-sky-hook',
        },
      ),
      sender,
    );

    expect(sender.messages.single.toJson(), {
      'version': 1,
      'id': 'share-1',
      'type': 'share.route.failed',
      'direction': 'native-to-web',
      'payload': {
        'ok': false,
        'error': {
          'code': 'native_share_unavailable',
          'message': 'Native share is unavailable.',
        },
      },
    });
  });
}

class RecordingNativeShareService implements NativeShareService {
  RecordingNativeShareService(this.result);

  final NativeShareResult result;
  final List<NativeShareRouteRequest> requests = [];

  @override
  Future<NativeShareResult> shareRoute(NativeShareRouteRequest request) async {
    requests.add(request);
    return result;
  }
}

class RecordingBridgeSender implements BridgeSender {
  final List<BridgeMessage> messages = [];

  @override
  Future<void> send(BridgeMessage message) async {
    messages.add(message);
  }
}
