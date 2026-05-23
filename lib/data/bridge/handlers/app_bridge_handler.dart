import 'dart:async';
import 'dart:io';

import '../bridge_handler.dart';
import '../bridge_message.dart';

class AppBridgeContext {
  const AppBridgeContext({
    this.platform = 'unknown',
    this.appVersion = '0.1.0',
    this.buildNumber = '1',
    this.sessionState = 'anonymous',
    this.capabilities = const <String>[
      'auth.native',
      'auth.sessionSync',
      'navigation.external',
      'share',
      'debug',
    ],
  });

  final String platform;
  final String appVersion;
  final String buildNumber;
  final String sessionState;
  final List<String> capabilities;

  factory AppBridgeContext.current() {
    return AppBridgeContext(
      platform: Platform.operatingSystem,
    );
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'platform': platform,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'sessionState': sessionState,
      'capabilities': capabilities,
    };
  }
}

class AppBridgeHandler implements BridgeHandler {
  const AppBridgeHandler({
    this.context,
  });

  final AppBridgeContext? context;

  @override
  bool canHandle(BridgeMessage message) {
    return message.type == 'app.web.ready' &&
        message.direction == BridgeDirection.webToNative;
  }

  @override
  FutureOr<void> handle(BridgeMessage message, BridgeSender sender) {
    final nativeContext = context ?? AppBridgeContext.current();

    return sender.send(
      BridgeMessage(
        version: 1,
        type: 'app.native.ready',
        direction: BridgeDirection.nativeToWeb,
        payload: nativeContext.toPayload(),
      ),
    );
  }
}
