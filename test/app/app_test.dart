import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/app/app.dart';
import 'package:granite_climbing_app/core/connectivity/network_status.dart';
import 'package:granite_climbing_app/core/connectivity/network_status_service.dart';
import 'package:granite_climbing_app/shared/widgets/app_start_screen.dart';
import 'package:granite_climbing_app/shared/widgets/granite_logo.dart';

class FakeNetworkStatusService implements NetworkStatusService {
  FakeNetworkStatusService(this.status);

  final NetworkStatus? status;
  final StreamController<NetworkStatus> _controller =
      StreamController.broadcast();

  @override
  Future<NetworkStatus> currentStatus() async {
    final current = status;
    if (current == null) {
      return Completer<NetworkStatus>().future;
    }
    return current;
  }

  @override
  Stream<NetworkStatus> watchStatus() => _controller.stream;
}

class ControlledNetworkStatusService implements NetworkStatusService {
  final StreamController<NetworkStatus> _controller =
      StreamController.broadcast();
  final Completer<NetworkStatus> _currentStatus = Completer<NetworkStatus>();

  @override
  Future<NetworkStatus> currentStatus() => _currentStatus.future;

  @override
  Stream<NetworkStatus> watchStatus() => _controller.stream;

  void emit(NetworkStatus status) => _controller.add(status);

  void completeCurrentStatus(NetworkStatus status) {
    _currentStatus.complete(status);
  }
}

class ThrowingNetworkStatusService implements NetworkStatusService {
  const ThrowingNetworkStatusService();

  @override
  Future<NetworkStatus> currentStatus() async {
    throw Exception('connectivity unavailable');
  }

  @override
  Stream<NetworkStatus> watchStatus() => const Stream.empty();
}

class QueuedNetworkStatusService implements NetworkStatusService {
  QueuedNetworkStatusService(this.statuses);

  final List<NetworkStatus> statuses;
  var _callCount = 0;

  @override
  Future<NetworkStatus> currentStatus() async {
    final index =
        _callCount < statuses.length ? _callCount : statuses.length - 1;
    _callCount += 1;
    return statuses[index];
  }

  @override
  Stream<NetworkStatus> watchStatus() => const Stream.empty();
}

void main() {
  testWidgets('shows the app start screen while network status is loading',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: FakeNetworkStatusService(null),
      ),
    );

    expect(find.byType(GraniteLogo), findsOneWidget);
    expect(find.byType(GraniteLoadingSpinner), findsOneWidget);
  });

  testWidgets('shows the offline web bundle when the device is offline',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: FakeNetworkStatusService(NetworkStatus.offline),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: Text('offline-webview: $assetPath'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('offline-webview: assets/offline_web/index.html'),
      findsOneWidget,
    );
  });

  testWidgets('shows bundled offline web content without opening local storage',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: FakeNetworkStatusService(NetworkStatus.offline),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: Text('offline-webview: $assetPath'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('offline-webview: assets/offline_web/index.html'),
      findsOneWidget,
    );
  });

  testWidgets('shows web content when the device is online', (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: FakeNetworkStatusService(NetworkStatus.online),
        webViewFirstLoadWarningDelay: const Duration(milliseconds: 500),
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: Text('offline-webview: $assetPath'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('webview: https://granite.kr/'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('연결이 불안정합니다.'), findsOneWidget);
  });

  testWidgets('shows web content with an unstable notice when network is slow',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: FakeNetworkStatusService(NetworkStatus.slow),
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: Text('offline-webview: $assetPath'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
    expect(find.text('연결이 불안정합니다.'), findsOneWidget);

    await tester.tap(find.text('저장된 코스 보기'));
    await tester.pump();

    expect(
      find.text('offline-webview: assets/offline_web/index.html'),
      findsOneWidget,
    );
  });

  testWidgets('uses the offline bundle when the server is unreachable',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: FakeNetworkStatusService(NetworkStatus.blocked),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: Text('offline-webview: $assetPath'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('offline-webview: assets/offline_web/index.html'),
      findsOneWidget,
    );
  });

  testWidgets('keeps a newer watched status over stale initial status',
      (tester) async {
    final networkStatusService = ControlledNetworkStatusService();

    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: networkStatusService,
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: Text('offline-webview: $assetPath'),
        ),
      ),
    );

    await tester.pump();
    networkStatusService.emit(NetworkStatus.online);
    await tester.pump();
    expect(find.text('webview: https://granite.kr/'), findsOneWidget);

    networkStatusService.completeCurrentStatus(NetworkStatus.offline);
    await tester.pump();

    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
    expect(
      find.text('offline-webview: assets/offline_web/index.html'),
      findsNothing,
    );
  });

  testWidgets('falls back to offline web content when initial status throws',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: const ThrowingNetworkStatusService(),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: Text('offline-webview: $assetPath'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('offline-webview: assets/offline_web/index.html'),
      findsOneWidget,
    );
  });

  testWidgets('keeps the app start screen for the configured startup delay',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: FakeNetworkStatusService(NetworkStatus.online),
        startupDelay: const Duration(milliseconds: 500),
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(GraniteLogo), findsOneWidget);
    expect(find.text('webview: https://granite.kr/'), findsNothing);

    await tester.pump(const Duration(milliseconds: 499));
    expect(find.byType(GraniteLogo), findsOneWidget);
    expect(find.text('webview: https://granite.kr/'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
  });

  testWidgets('offline retry switches back to online web content',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        networkStatusService: QueuedNetworkStatusService([
          NetworkStatus.offline,
          NetworkStatus.online,
        ]),
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
        offlineWebViewBuilder: (context, assetPath, onRetryOnline) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => onRetryOnline?.call(),
            child: const Text('온라인으로 다시 시도'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('온라인으로 다시 시도'), findsOneWidget);
    expect(find.text('webview: https://granite.kr/'), findsNothing);

    await tester.tap(find.text('온라인으로 다시 시도'));
    await tester.pump();

    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
  });
}
