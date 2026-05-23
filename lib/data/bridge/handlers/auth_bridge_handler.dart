import 'dart:async';

import '../../../features/auth/native_auth_service.dart';
import '../bridge_handler.dart';
import '../bridge_message.dart';

class AuthBridgeHandler implements BridgeHandler {
  const AuthBridgeHandler({
    this.authService = const DevNativeAuthService(),
  });

  final NativeAuthService authService;

  @override
  bool canHandle(BridgeMessage message) {
    return message.type == 'auth.login.requested' &&
        message.direction == BridgeDirection.webToNative;
  }

  @override
  Future<void> handle(BridgeMessage message, BridgeSender sender) async {
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
  }

  static String? _readString(Object? value) {
    return value is String ? value : null;
  }
}
