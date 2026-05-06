import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/core/constants/app_constants.dart';
import 'package:granite_climbing_app/features/offline_webview/offline_webview_screen.dart';
import 'package:granite_climbing_app/shared/widgets/app_start_screen.dart';
import 'package:granite_climbing_app/shared/widgets/granite_logo.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  testWidgets('offline webview loads the bundled html asset', (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      const MaterialApp(
        home: OfflineWebViewScreen(),
      ),
    );

    expect(platform.controller?.javaScriptMode, JavaScriptMode.unrestricted);
    expect(platform.controller?.overScrollMode, WebViewOverScrollMode.never);
    expect(platform.controller?.loadedAsset, AppConstants.offlineWebAssetPath);
  });

  testWidgets('offline webview keeps the start screen until html loads',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;

    await tester.pumpWidget(
      const MaterialApp(
        home: OfflineWebViewScreen(),
      ),
    );

    expect(find.byType(GraniteLogo), findsOneWidget);
    expect(find.byType(GraniteLoadingSpinner), findsOneWidget);

    platform.navigationDelegate?.onPageFinished?.call('asset');
    await tester.pump();

    expect(find.byType(GraniteLogo), findsNothing);
    expect(find.byType(GraniteLoadingSpinner), findsNothing);
  });

  testWidgets('offline webview shows a native header and retries online',
      (tester) async {
    final platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineWebViewScreen(
          onRetryOnline: () async {
            retryCount += 1;
            return false;
          },
        ),
      ),
    );

    platform.navigationDelegate?.onPageFinished?.call('asset');
    await tester.pump();

    expect(find.byKey(const ValueKey('offline-native-header')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('offline-floating-controls')), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('오프라인'), findsOneWidget);
    expect(find.byKey(const ValueKey('offline-retry-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('offline-menu-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('offline-retry-button')));
    await tester.pump();

    expect(retryCount, 1);
    expect(find.text('아직 온라인 연결을 확인할 수 없습니다.'), findsOneWidget);
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
  String? loadedAsset;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    this.javaScriptMode = javaScriptMode;
  }

  @override
  Future<void> setOverScrollMode(WebViewOverScrollMode mode) async {
    overScrollMode = mode;
  }

  @override
  Future<void> loadFlutterAsset(String key) async {
    loadedAsset = key;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
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
