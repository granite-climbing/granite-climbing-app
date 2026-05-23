import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_controller.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  test('attaches the FlutterWebView JavaScript channel', () async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final webViewController = WebViewController();

    await const BridgeController().attachTo(webViewController);

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
  FutureOr<void> handle(BridgeMessage message) {
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

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    javaScriptChannels.add(javaScriptChannelParams);
  }
}
