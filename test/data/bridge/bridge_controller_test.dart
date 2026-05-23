import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_controller.dart';
import 'package:granite_climbing_app/data/bridge/bridge_debug_log.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  test('attaches the FlutterWebView JavaScript channel', () async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final webViewController = WebViewController();

    await BridgeController().attachTo(webViewController);

    expect(platform.controller?.javaScriptChannels.single.name,
        BridgeController.channelName);
  });

  test('dispatches decoded channel messages to matching handlers', () async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final webViewController = WebViewController();
    final handler = RecordingBridgeHandler({'app.web.ready'});

    await BridgeController(handlers: [handler]).attachTo(webViewController);

    platform.controller?.javaScriptChannels.single.onMessageReceived(
      const JavaScriptMessage(
        message: '''
        {
          "version": 1,
          "type": "app.web.ready",
          "direction": "web-to-native",
          "payload": {
            "url": "http://localhost:3000"
          }
        }
        ''',
      ),
    );

    expect(handler.messages.single.type, 'app.web.ready');
    expect(handler.messages.single.payload, {
      'url': 'http://localhost:3000',
    });
  });

  test('ignores invalid channel messages without dispatching', () async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final webViewController = WebViewController();
    final handler = RecordingBridgeHandler({'app.web.ready'});

    await BridgeController(handlers: [handler]).attachTo(webViewController);

    platform.controller?.javaScriptChannels.single.onMessageReceived(
      const JavaScriptMessage(message: 'not-json'),
    );

    expect(handler.messages, isEmpty);
  });

  test('sends native-to-web messages through GraniteBridge.receive', () async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final webViewController = WebViewController();

    final bridgeController = BridgeController();
    await bridgeController.attachTo(webViewController);
    await bridgeController.send(
      const BridgeMessage(
        version: 1,
        type: 'app.native.ready',
        direction: BridgeDirection.nativeToWeb,
        payload: {
          'platform': 'ios',
        },
      ),
    );

    expect(
      platform.controller?.javaScripts.single,
      'window.GraniteBridge?.receive({"version":1,"type":"app.native.ready","direction":"native-to-web","payload":{"platform":"ios"}});',
    );
  });

  test('records decoded inbound and outbound messages in the debug log',
      () async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final webViewController = WebViewController();
    final debugLog = BridgeDebugLog(now: () => 1710000000000);

    final bridgeController = BridgeController(debugLog: debugLog);
    await bridgeController.attachTo(webViewController);

    platform.controller?.javaScriptChannels.single.onMessageReceived(
      const JavaScriptMessage(
        message: '''
        {
          "version": 1,
          "type": "auth.session.sync.completed",
          "direction": "web-to-native",
          "payload": {
            "email": "climber@example.com"
          }
        }
        ''',
      ),
    );
    await bridgeController.send(
      const BridgeMessage(
        version: 1,
        type: 'auth.session.sync.requested',
        direction: BridgeDirection.nativeToWeb,
        payload: {
          'handoffCode': 'handoff-secret',
        },
      ),
    );

    expect(debugLog.entries.map((entry) => entry.direction.value), [
      'inbound',
      'outbound',
    ]);
    expect(debugLog.entries.first.payload, {
      'email': '[redacted]',
    });
    expect(debugLog.entries.last.payload, {
      'handoffCode': '[redacted]',
    });
  });
}

class RecordingBridgeHandler implements BridgeHandler {
  RecordingBridgeHandler(this.supportedTypes);

  final Set<String> supportedTypes;
  final List<BridgeMessage> messages = [];

  @override
  bool canHandle(BridgeMessage message) {
    return supportedTypes.contains(message.type);
  }

  @override
  FutureOr<void> handle(BridgeMessage message, BridgeSender sender) {
    messages.add(message);
  }
}

class RecordingWebViewPlatform extends WebViewPlatform {
  RecordingPlatformWebViewController? controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = RecordingPlatformWebViewController(params);
  }
}

class RecordingPlatformWebViewController extends PlatformWebViewController {
  RecordingPlatformWebViewController(super.params) : super.implementation();

  final List<JavaScriptChannelParams> javaScriptChannels = [];
  final List<String> javaScripts = [];

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    javaScriptChannels.add(javaScriptChannelParams);
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    javaScripts.add(javaScript);
  }
}
