import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';

import 'bridge_codec.dart';
import 'bridge_debug_log.dart';
import 'bridge_handler.dart';
import 'bridge_message.dart';

class BridgeController implements BridgeSender {
  BridgeController({
    this.handlers = const <BridgeHandler>[],
    this.debugLog,
  });

  static const channelName = 'FlutterWebView';

  final List<BridgeHandler> handlers;
  final BridgeDebugLog? debugLog;
  WebViewController? _webViewController;

  Future<void> attachTo(WebViewController controller) {
    _webViewController = controller;
    return controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (message) => handleRawMessage(message.message),
    );
  }

  @override
  Future<void> send(BridgeMessage message) async {
    final webViewController = _webViewController;
    if (webViewController == null) return;

    debugLog?.recordOutbound(message);
    await webViewController.runJavaScript(
      'window.GraniteBridge?.receive(${BridgeCodec.encode(message)});',
    );
  }

  void handleRawMessage(String source) {
    final message = _tryDecode(source);
    if (message == null) return;

    debugLog?.recordInbound(message);
    for (final handler in handlers) {
      if (!handler.canHandle(message)) continue;

      final result = handler.handle(message, this);
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
