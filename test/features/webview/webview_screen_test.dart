import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';
import 'package:granite_climbing_app/features/navigation/native_map_service.dart';
import 'package:granite_climbing_app/features/webview/webview_screen.dart';
import 'package:granite_climbing_app/shared/widgets/app_start_screen.dart';
import 'package:granite_climbing_app/shared/widgets/granite_logo.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  testWidgets('webview keeps content inside top and bottom safe areas',
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
    expect(safeArea.bottom, isTrue);
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

  testWidgets('webview sends native login failures back to the login page',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/app'),
          nativeSocialLoginService: ThrowingNativeSocialLoginService(),
        ),
      ),
    );

    platform.controller?.javaScriptChannels.single.onMessageReceived(
      const JavaScriptMessage(
        message: '''
        {
          "version": 1,
          "type": "auth.native.login.requested",
          "direction": "web-to-native",
          "payload": {
            "provider": "kakao",
            "returnTo": "/me"
          }
        }
        ''',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(platform.controller?.loadedUri, Uri.parse('https://granite.kr/app'));
    expect(
      platform.controller?.javaScripts.last,
      contains('auth.native.login.failed'),
    );
  });

  testWidgets('webview submits successful native auth through POST loadRequest',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: WebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/app'),
          nativeSocialLoginService: SuccessfulNativeSocialLoginService(
            const NativeSocialLoginResult(
              provider: 'apple',
              accessToken: '',
              idToken: 'apple-id-token',
            ),
          ),
        ),
      ),
    );

    platform.controller?.javaScriptChannels.single.onMessageReceived(
      const JavaScriptMessage(
        message: '''
        {
          "version": 1,
          "type": "auth.native.login.requested",
          "direction": "web-to-native",
          "payload": {
            "provider": "apple",
            "returnTo": "/me"
          }
        }
        ''',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final request = platform.controller?.loadRequests.last;
    expect(
        request?.uri, Uri.parse('https://granite.kr/api/auth/native/session'));
    expect(request?.method, LoadRequestMethod.post);
    expect(
        request?.headers['content-type'], 'application/x-www-form-urlencoded');
    expect(Uri.splitQueryString(utf8.decode(request?.body ?? const [])), {
      'provider': 'apple',
      'idToken': 'apple-id-token',
      'returnTo': '/me',
    });
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

  testWidgets('webview clears the start screen when initial loading fails',
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

    platform.navigationDelegate?.onWebResourceError?.call(
      const WebResourceError(
        errorCode: -2,
        description: 'Host lookup failed',
        errorType: WebResourceErrorType.hostLookup,
        isForMainFrame: true,
        url: 'https://granite.kr/',
      ),
    );
    await tester.pump();

    expect(find.byType(GraniteLogo), findsNothing);
    expect(find.byType(GraniteLoadingSpinner), findsNothing);
    expect(find.text('페이지를 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('webview retries the current page from the loading error screen',
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

    platform.navigationDelegate?.onWebResourceError?.call(
      const WebResourceError(
        errorCode: -2,
        description: 'Host lookup failed',
        errorType: WebResourceErrorType.hostLookup,
        isForMainFrame: true,
        url: 'https://granite.kr/',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('다시 시도'));
    await tester.pump();

    expect(platform.controller?.reloadCount, 1);
    expect(find.byType(GraniteLoadingSpinner), findsOneWidget);
    expect(find.text('페이지를 불러오지 못했습니다'), findsNothing);
  });

  testWidgets('webview shows the retry screen for initial HTTP errors',
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

    platform.navigationDelegate?.onHttpError?.call(
      HttpResponseError(
        request: WebResourceRequest(uri: Uri.parse('https://granite.kr/')),
        response: WebResourceResponse(
          uri: Uri.parse('https://granite.kr/'),
          statusCode: 503,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('페이지를 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
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

  testWidgets('system back navigates webview history before closing app',
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

    platform.controller?.canGoBackResult = true;

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(platform.controller?.goBackCount, 1);
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
  final List<LoadRequestParams> loadRequests = [];
  PlatformNavigationDelegate? navigationDelegate;
  var canGoBackResult = false;
  var goBackCount = 0;
  var reloadCount = 0;
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
    loadRequests.add(params);
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

  @override
  Future<bool> canGoBack() async {
    return canGoBackResult;
  }

  @override
  Future<void> goBack() async {
    goBackCount += 1;
  }

  @override
  Future<void> reload() async {
    reloadCount += 1;
  }
}

class SuccessfulNativeSocialLoginService implements NativeSocialLoginService {
  const SuccessfulNativeSocialLoginService(this.result);

  final NativeSocialLoginResult result;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    return result;
  }
}

class RecordingPlatformNavigationDelegate extends PlatformNavigationDelegate {
  RecordingPlatformNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;
  HttpResponseErrorCallback? onHttpError;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    this.onWebResourceError = onWebResourceError;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {
    this.onHttpError = onHttpError;
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

class ThrowingNativeSocialLoginService implements NativeSocialLoginService {
  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    throw const NativeSocialLoginException('Native login failed.');
  }
}
