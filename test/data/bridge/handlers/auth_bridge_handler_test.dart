import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/auth_bridge_handler.dart';
import 'package:granite_climbing_app/features/auth/native_auth_service.dart';

void main() {
  test('starts native login and responds with the matching request id',
      () async {
    final authService = RecordingNativeAuthService(
      const NativeLoginStart(provider: 'native'),
    );
    final sender = RecordingBridgeSender();
    final handler = AuthBridgeHandler(authService: authService);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        id: 'login-1',
        type: 'auth.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'returnTo': '/me',
        },
      ),
      sender,
    );

    expect(authService.requests.single.returnTo, '/me');
    expect(sender.messages.single.toJson(), {
      'version': 1,
      'id': 'login-1',
      'type': 'auth.login.started',
      'direction': 'native-to-web',
      'payload': {
        'provider': 'native',
      },
    });
  });

  test('ignores bridge messages that are not native login requests', () {
    const handler = AuthBridgeHandler();

    expect(
      handler.canHandle(
        const BridgeMessage(
          version: 1,
          type: 'app.web.ready',
          direction: BridgeDirection.webToNative,
        ),
      ),
      isFalse,
    );
  });
}

class RecordingNativeAuthService implements NativeAuthService {
  RecordingNativeAuthService(this.start);

  final NativeLoginStart start;
  final List<NativeLoginRequest> requests = [];

  @override
  Future<NativeLoginStart> startLogin(NativeLoginRequest request) async {
    requests.add(request);
    return start;
  }
}

class RecordingBridgeSender implements BridgeSender {
  final List<BridgeMessage> messages = [];

  @override
  Future<void> send(BridgeMessage message) async {
    messages.add(message);
  }
}
