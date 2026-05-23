import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/auth_bridge_handler.dart';
import 'package:granite_climbing_app/features/auth/native_auth_service.dart';
import 'package:granite_climbing_app/features/auth/session_handoff_service.dart';

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
    expect(sender.messages.first.toJson(), {
      'version': 1,
      'id': 'login-1',
      'type': 'auth.login.started',
      'direction': 'native-to-web',
      'payload': {
        'provider': 'native',
      },
    });
  });

  test('requests web session sync after native login starts', () async {
    final authService = RecordingNativeAuthService(
      const NativeLoginStart(provider: 'native'),
    );
    final handoffService = RecordingSessionHandoffService(
      const SessionHandoff(
        handoffCode: 'handoff-1',
        returnTo: '/me',
        reason: 'native_login',
      ),
    );
    final sender = RecordingBridgeSender();
    final handler = AuthBridgeHandler(
      authService: authService,
      sessionHandoffService: handoffService,
      sessionSyncIdFactory: () => 'session-sync-1',
    );

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

    expect(handoffService.requests.single.returnTo, '/me');
    expect(sender.messages.map((message) => message.type), [
      'auth.login.started',
      'auth.session.sync.requested',
    ]);
    expect(sender.messages.last.toJson(), {
      'version': 1,
      'id': 'session-sync-1',
      'type': 'auth.session.sync.requested',
      'direction': 'native-to-web',
      'payload': {
        'handoffCode': 'handoff-1',
        'returnTo': '/me',
        'reason': 'native_login',
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

  test('accepts legacy web OAuth completion without starting native login',
      () async {
    final authService = RecordingNativeAuthService(
      const NativeLoginStart(provider: 'native'),
    );
    final handoffService = RecordingSessionHandoffService(
      const SessionHandoff(
        handoffCode: 'handoff-1',
        returnTo: '/me',
      ),
    );
    final sender = RecordingBridgeSender();
    final handler = AuthBridgeHandler(
      authService: authService,
      sessionHandoffService: handoffService,
    );
    const message = BridgeMessage(
      version: 1,
      type: 'auth.login.completed',
      direction: BridgeDirection.webToNative,
      payload: {
        'provider': 'google',
        'returnTo': '/me',
        'legacyType': 'granite.auth.complete',
      },
    );

    expect(handler.canHandle(message), isTrue);

    await handler.handle(message, sender);

    expect(authService.requests, isEmpty);
    expect(handoffService.requests, isEmpty);
    expect(sender.messages, isEmpty);
  });

  test('logs out native auth and responds with completion', () async {
    final authService = RecordingNativeAuthService(
      const NativeLoginStart(provider: 'native'),
    );
    final sender = RecordingBridgeSender();
    final handler = AuthBridgeHandler(authService: authService);

    await handler.handle(
      const BridgeMessage(
        version: 1,
        id: 'logout-1',
        type: 'auth.logout.requested',
        direction: BridgeDirection.webToNative,
      ),
      sender,
    );

    expect(authService.logoutCount, 1);
    expect(sender.messages.single.toJson(), {
      'version': 1,
      'id': 'logout-1',
      'type': 'auth.logout.completed',
      'direction': 'native-to-web',
      'payload': <String, Object?>{},
    });
  });
}

class RecordingNativeAuthService implements NativeAuthService {
  RecordingNativeAuthService(this.start);

  final NativeLoginStart start;
  final List<NativeLoginRequest> requests = [];
  var logoutCount = 0;

  @override
  Future<NativeLoginStart> startLogin(NativeLoginRequest request) async {
    requests.add(request);
    return start;
  }

  @override
  Future<void> logout() async {
    logoutCount += 1;
  }
}

class RecordingSessionHandoffService implements SessionHandoffService {
  RecordingSessionHandoffService(this.handoff);

  final SessionHandoff handoff;
  final List<SessionHandoffRequest> requests = [];

  @override
  Future<SessionHandoff> createHandoff(SessionHandoffRequest request) async {
    requests.add(request);
    return handoff;
  }
}

class RecordingBridgeSender implements BridgeSender {
  final List<BridgeMessage> messages = [];

  @override
  Future<void> send(BridgeMessage message) async {
    messages.add(message);
  }
}
