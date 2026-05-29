import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/navigation/native_map_service.dart';
import 'package:granite_climbing_app/features/webview/webview_screen.dart';
import 'package:granite_climbing_app/shared/widgets/app_start_screen.dart';
import 'package:granite_climbing_app/shared/widgets/granite_logo.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  testWidgets('webview keeps the top safe area and fills the bottom',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewFrame(
          child: SizedBox.shrink(),
        ),
      ),
    );

    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
    expect(safeArea.top, isTrue);
    expect(safeArea.bottom, isFalse);
  });

  testWidgets('webview disables native overscroll bounce', (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(platform.controller?.javaScriptMode, JavaScriptMode.unrestricted);
    expect(platform.controller?.overScrollMode, WebViewOverScrollMode.never);
    expect(platform.controller?.loadedUri, Uri.parse('https://granite.kr/'));
  });

  testWidgets('webview registers the FlutterWebView bridge channel',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(
      platform.controller?.javaScriptChannels.single.name,
      'FlutterWebView',
    );
  });

  testWidgets('webview opens the preferred native map from bridge messages',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    final launcher = RecordingNativeMapLauncher();

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
          nativeMapService: NativeMapService(
            platform: NativeMapPlatform.ios,
            launcher: launcher,
          ),
        ),
      ),
    );

    platform.controller?.javaScriptChannels.single.onMessageReceived(
      const JavaScriptMessage(
        message: '''
        {
          "version": 1,
          "type": "navigation.map.open.requested",
          "direction": "web-to-native",
          "payload": {
            "label": "수락산 주차장",
            "latitude": 37.682312,
            "longitude": 127.058412
          }
        }
        ''',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('지도 앱 선택'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(launcher.launchedUrls, [
      Uri.parse(
        'https://maps.apple.com/?ll=37.682312,127.058412&q=%EC%88%98%EB%9D%BD%EC%82%B0%20%EC%A3%BC%EC%B0%A8%EC%9E%A5',
      ),
    ]);
  });

  testWidgets('webview does not show native bottom navigation', (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(find.text('홈'), findsNothing);
    expect(find.text('프로젝트'), findsNothing);
    expect(find.text('기록'), findsNothing);
    expect(find.text('마이'), findsNothing);
  });

  testWidgets('webview does not send native nav bridge messages',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(platform.controller?.javaScripts, isEmpty);
  });

  testWidgets('webview omits native bottom navigation with test builder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
          webViewBuilder: (context, url) => Text('webview: $url'),
        ),
      ),
    );

    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
    expect(find.text('홈'), findsNothing);
    expect(find.text('프로젝트'), findsNothing);
    expect(find.text('기록'), findsNothing);
    expect(find.text('마이'), findsNothing);
  });

  testWidgets('webview keeps the start screen until the first page loads',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(find.byType(GraniteLogo), findsOneWidget);
    expect(find.byType(GraniteLoadingSpinner), findsOneWidget);

    platform.navigationDelegate?.onPageFinished?.call('https://granite.kr/');
    await tester.pump();

    expect(find.byType(GraniteLogo), findsNothing);
    expect(find.byType(GraniteLoadingSpinner), findsNothing);
  });

  testWidgets('webview does not show offline fallback controls',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 10));

    expect(find.text('연결이 불안정합니다.'), findsNothing);
    expect(find.text('저장된 코스 보기'), findsNothing);
  });
}

class RecordingWebViewPlatform extends WebViewPlatform {
  RecordingPlatformWebViewController? controller;
  RecordingPlatformNavigationDelegate? navigationDelegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = RecordingPlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return RecordingPlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return navigationDelegate = RecordingPlatformNavigationDelegate(params);
  }
}

class RecordingPlatformWebViewController extends PlatformWebViewController {
  RecordingPlatformWebViewController(super.params) : super.implementation();

  JavaScriptMode? javaScriptMode;
  WebViewOverScrollMode? overScrollMode;
  Uri? loadedUri;
  PlatformNavigationDelegate? navigationDelegate;
  final List<JavaScriptChannelParams> javaScriptChannels = [];
  final List<String> javaScripts = [];

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    this.javaScriptMode = javaScriptMode;
  }

  @override
  Future<void> setOverScrollMode(WebViewOverScrollMode mode) async {
    overScrollMode = mode;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedUri = params.uri;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigationDelegate = handler;
  }

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

class RecordingPlatformNavigationDelegate extends PlatformNavigationDelegate {
  RecordingPlatformNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? onPageFinished;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }
}

class RecordingPlatformWebViewWidget extends PlatformWebViewWidget {
  RecordingPlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class RecordingNativeMapLauncher implements NativeMapLauncher {
  RecordingNativeMapLauncher({
    this.canLaunchResults = const <Uri, bool>{},
  });

  final Map<Uri, bool> canLaunchResults;
  final List<Uri> launchedUrls = [];

  @override
  Future<bool> canLaunch(Uri url) async => canLaunchResults[url] ?? false;

  @override
  Future<void> launch(Uri url) async {
    launchedUrls.add(url);
  }
}
