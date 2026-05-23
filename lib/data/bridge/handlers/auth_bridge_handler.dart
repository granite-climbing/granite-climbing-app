import 'dart:async';

import '../../../features/auth/native_auth_service.dart';
import '../../../features/auth/session_handoff_service.dart';
import '../bridge_handler.dart';
import '../bridge_message.dart';

class AuthBridgeHandler implements BridgeHandler {
  const AuthBridgeHandler({
    this.authService = const DevNativeAuthService(),
    this.sessionHandoffService = const DevSessionHandoffService(),
    this.sessionSyncIdFactory = _defaultSessionSyncId,
  });

  final NativeAuthService authService;
  final SessionHandoffService sessionHandoffService;
  final String Function() sessionSyncIdFactory;

  @override
  bool canHandle(BridgeMessage message) {
    return (message.type == 'auth.login.requested' ||
            message.type == 'auth.login.completed' ||
            message.type == 'auth.logout.requested') &&
        message.direction == BridgeDirection.webToNative;
  }

  @override
  Future<void> handle(BridgeMessage message, BridgeSender sender) async {
    if (message.type == 'auth.login.completed') {
      return;
    }

    if (message.type == 'auth.logout.requested') {
      await authService.logout();
      await sender.send(
        BridgeMessage(
          version: 1,
          id: message.id,
          type: 'auth.logout.completed',
          direction: BridgeDirection.nativeToWeb,
        ),
      );
      return;
    }

    final start = await authService.startLogin(
      NativeLoginRequest(
        returnTo: _readString(message.payload['returnTo']),
      ),
    );

    await sender.send(
      BridgeMessage(
        version: 1,
        id: message.id,
        type: 'auth.login.started',
        direction: BridgeDirection.nativeToWeb,
        payload: start.toPayload(),
      ),
    );

    final handoff = await sessionHandoffService.createHandoff(
      SessionHandoffRequest(
        returnTo: _readString(message.payload['returnTo']),
      ),
    );

    await sender.send(
      BridgeMessage(
        version: 1,
        id: sessionSyncIdFactory(),
        type: 'auth.session.sync.requested',
        direction: BridgeDirection.nativeToWeb,
        payload: handoff.toPayload(),
      ),
    );
  }

  static String? _readString(Object? value) {
    return value is String ? value : null;
  }

  static String _defaultSessionSyncId() {
    return 'session-sync-${DateTime.now().millisecondsSinceEpoch}';
  }
}
