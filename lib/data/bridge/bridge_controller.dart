import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';

import 'bridge_codec.dart';
import 'bridge_handler.dart';
import 'bridge_message.dart';

class BridgeController {
  const BridgeController({
    this.handlers = const <BridgeHandler>[],
  });

  static const channelName = 'FlutterWebView';

  final List<BridgeHandler> handlers;

  Future<void> attachTo(WebViewController controller) {
    return controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (message) => handleRawMessage(message.message),
    );
  }

  void handleRawMessage(String source) {
    final message = _tryDecode(source);
    if (message == null) return;

    for (final handler in handlers) {
      if (!handler.canHandle(message)) continue;

      final result = handler.handle(message);
      if (result is Future<void>) {
        unawaited(result);
      }
      return;
    }
  }

  static BridgeMessage? _tryDecode(String source) {
    try {
      return BridgeCodec.decode(source);
    } on BridgeCodecException {
      return null;
    }
  }
}
