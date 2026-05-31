import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_controller.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/app_bridge_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  test('responds to app.web.ready with native context', () async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final webViewController = WebViewController();
    final handler = AppBridgeHandler(
      context: const AppBridgeContext(
        platform: 'ios',
        appVersion: '0.1.0',
        buildNumber: '1',
        sessionState: 'anonymous',
        capabilities: ['auth.native', 'auth.sessionSync', 'share'],
      ),
    );

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

    final script = platform.controller?.javaScripts.single;
    expect(script, isNotNull);
    expect(script, startsWith('window.GraniteBridge?.receive('));

    final encodedMessage = script!
        .replaceFirst('window.GraniteBridge?.receive(', '')
        .replaceFirst(');', '');
    final message = jsonDecode(encodedMessage) as Map<String, Object?>;

    expect(message, {
      'version': 1,
      'type': 'app.native.ready',
      'direction': 'native-to-web',
      'payload': {
        'platform': 'ios',
        'appVersion': '0.1.0',
        'buildNumber': '1',
        'sessionState': 'anonymous',
        'capabilities': ['auth.native', 'auth.sessionSync', 'share'],
      },
    });
  });

  test('ignores bridge messages that are not app.web.ready', () {
    const handler = AppBridgeHandler();

    expect(
      handler.canHandle(
        const BridgeMessage(
          version: 1,
          type: 'auth.login.requested',
          direction: BridgeDirection.webToNative,
        ),
      ),
      isFalse,
    );
  });

  test('does not advertise native auth by default', () {
    final context = AppBridgeContext.current();

    expect(context.capabilities, isNot(contains('auth.native')));
    expect(context.capabilities, isNot(contains('auth.sessionSync')));
    expect(context.capabilities, contains('navigation.external'));
    expect(context.capabilities, contains('share'));
  });

  test('can advertise native auth for explicit smoke builds', () {
    final context = AppBridgeContext.current(enableNativeAuth: true);

    expect(context.capabilities, contains('auth.native'));
    expect(context.capabilities, contains('auth.sessionSync'));
  });
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
