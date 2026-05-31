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

    final loginRequest = NativeLoginRequest(
      returnTo: _readString(message.payload['returnTo']),
      providerHint: _readString(message.payload['provider']),
      surface: _readString(message.payload['surface']),
    );

    final NativeLoginStart start;
    try {
      start = await authService.startLogin(loginRequest);
    } catch (_) {
      await _sendFailed(
        sender,
        id: message.id,
        type: 'auth.login.failed',
        message: 'Native login could not be started.',
      );
      return;
    }

    await sender.send(
      BridgeMessage(
        version: 1,
        id: message.id,
        type: 'auth.login.started',
        direction: BridgeDirection.nativeToWeb,
        payload: start.toPayload(),
      ),
    );

    final sessionSyncId = sessionSyncIdFactory();
    final SessionHandoff handoff;
    try {
      handoff = await sessionHandoffService.createHandoff(
        SessionHandoffRequest(
          returnTo: loginRequest.returnTo,
        ),
      );
    } catch (_) {
      await _sendFailed(
        sender,
        id: sessionSyncId,
        type: 'auth.session.sync.failed',
        message: 'Native session could not be synced.',
      );
      return;
    }

    await sender.send(
      BridgeMessage(
        version: 1,
        id: sessionSyncId,
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

  Future<void> _sendFailed(
    BridgeSender sender, {
    required String? id,
    required String type,
    required String message,
  }) {
    return sender.send(
      BridgeMessage(
        version: 1,
        id: id,
        type: type,
        direction: BridgeDirection.nativeToWeb,
        payload: {
          'ok': false,
          'error': {
            'code': 'operation_failed',
            'message': message,
          },
        },
      ),
    );
  }
}
