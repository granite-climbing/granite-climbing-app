import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/webview/online_webview_screen.dart';
import 'package:granite_climbing_app/shared/widgets/app_start_screen.dart';
import 'package:granite_climbing_app/shared/widgets/granite_logo.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  testWidgets('online webview keeps the top safe area and fills the bottom',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnlineWebViewFrame(
          child: SizedBox.shrink(),
        ),
      ),
    );

    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
    expect(safeArea.top, isTrue);
    expect(safeArea.bottom, isFalse);
  });

  testWidgets('online webview disables native overscroll bounce',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineWebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(platform.controller?.javaScriptMode, JavaScriptMode.unrestricted);
    expect(platform.controller?.overScrollMode, WebViewOverScrollMode.never);
    expect(platform.controller?.loadedUri, Uri.parse('https://granite.kr/'));
  });

  testWidgets('online webview registers the FlutterWebView bridge channel',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineWebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(
      platform.controller?.javaScriptChannels.single.name,
      'FlutterWebView',
    );
  });

  testWidgets('online webview shows the native bottom navigation',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineWebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
        ),
      ),
    );

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('프로젝트'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);
  });

  testWidgets('online webview keeps native bottom navigation with test builder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineWebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
          webViewBuilder: (context, url) => Text('webview: $url'),
        ),
      ),
    );

    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('프로젝트'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);
  });

  testWidgets(
      'online webview keeps the start screen until the first page loads',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineWebViewScreen(
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

  testWidgets('online webview warns when first page load is too slow',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineWebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
          firstLoadWarningDelay: const Duration(milliseconds: 500),
          onOpenOffline: () {},
        ),
      ),
    );

    expect(find.text('연결이 불안정합니다.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 499));
    expect(find.text('연결이 불안정합니다.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('연결이 불안정합니다.'), findsOneWidget);
    expect(find.text('저장된 코스 보기'), findsOneWidget);
  });

  testWidgets('online webview does not warn when first page loads quickly',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineWebViewScreen(
          initialUrl: Uri.parse('https://granite.kr/'),
          firstLoadWarningDelay: const Duration(milliseconds: 500),
          onOpenOffline: () {},
        ),
      ),
    );

    platform.navigationDelegate?.onPageFinished?.call('https://granite.kr/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('연결이 불안정합니다.'), findsNothing);
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
