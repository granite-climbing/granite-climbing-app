import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/bridge/bridge_controller.dart';
import '../../data/bridge/bridge_handler.dart';
import '../../data/bridge/bridge_message.dart';
import '../../data/bridge/handlers/app_bridge_handler.dart';
import '../../data/bridge/handlers/auth_bridge_handler.dart';
import '../../data/bridge/handlers/navigation_bridge_handler.dart';
import '../../data/bridge/handlers/share_bridge_handler.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_start_screen.dart';

class OnlineWebViewScreen extends StatefulWidget {
  const OnlineWebViewScreen({
    required this.initialUrl,
    this.showUnstableConnectionBanner = false,
    this.firstLoadWarningDelay = const Duration(seconds: 8),
    this.onOpenOffline,
    this.webViewBuilder,
    this.bridgeHandlers = const <BridgeHandler>[
      AppBridgeHandler(),
      AuthBridgeHandler(),
      NavigationBridgeHandler(),
      ShareBridgeHandler(),
    ],
    super.key,
  });

  final Uri initialUrl;
  final bool showUnstableConnectionBanner;
  final Duration firstLoadWarningDelay;
  final VoidCallback? onOpenOffline;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;
  final List<BridgeHandler> bridgeHandlers;

  @override
  State<OnlineWebViewScreen> createState() => _OnlineWebViewScreenState();
}

class _OnlineWebViewScreenState extends State<OnlineWebViewScreen> {
  late final BridgeController _bridgeController;
  WebViewController? _controller;
  Timer? _firstLoadWarningTimer;
  var _isInitialPageLoaded = false;
  var _isFirstLoadSlow = false;
  var _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = _navIndexForUri(widget.initialUrl);
    _bridgeController = BridgeController(handlers: widget.bridgeHandlers);
    _startFirstLoadWarningTimer();

    if (widget.webViewBuilder == null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setOverScrollMode(WebViewOverScrollMode.never)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: _handlePageFinished,
          ),
        );

      unawaited(
        _bridgeController.attachTo(controller),
      );
      _controller = controller..loadRequest(widget.initialUrl);
    }
  }

  void _startFirstLoadWarningTimer() {
    if (widget.firstLoadWarningDelay <= Duration.zero) {
      _showFirstLoadWarning();
      return;
    }

    _firstLoadWarningTimer = Timer(
      widget.firstLoadWarningDelay,
      _showFirstLoadWarning,
    );
  }

  void _showFirstLoadWarning() {
    if (!mounted || _isInitialPageLoaded || _isFirstLoadSlow) return;

    setState(() => _isFirstLoadSlow = true);
  }

  void _handleInitialPageLoaded() {
    if (!mounted || _isInitialPageLoaded) return;

    _firstLoadWarningTimer?.cancel();
    setState(() {
      _isInitialPageLoaded = true;
      _isFirstLoadSlow = false;
    });
  }

  void _handlePageFinished(String url) {
    _handleInitialPageLoaded();
    _syncNavIndex(Uri.tryParse(url));
  }

  void _syncNavIndex(Uri? uri) {
    if (uri == null) return;

    final nextIndex = _navIndexForUri(uri);
    if (nextIndex == _currentNavIndex || !mounted) return;

    setState(() => _currentNavIndex = nextIndex);
  }

  void _handleNavDestinationSelected(int index) {
    final path = _navPathForIndex(index);
    if (path == null) return;

    if (index != _currentNavIndex) {
      setState(() => _currentNavIndex = index);
    }

    unawaited(
      _bridgeController.send(
        BridgeMessage(
          version: 1,
          type: 'navigation.open.webview.requested',
          direction: BridgeDirection.nativeToWeb,
          payload: {
            'path': path,
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstLoadWarningTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showUnstableConnectionBanner =
        widget.showUnstableConnectionBanner || _isFirstLoadSlow;
    final builder = widget.webViewBuilder;
    final child = builder == null
        ? OnlineWebViewFrame(
            child: WebViewWidget(controller: _controller!),
          )
        : builder(context, widget.initialUrl);

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentNavIndex,
        onDestinationSelected: _handleNavDestinationSelected,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: child),
          if (builder == null && !_isInitialPageLoaded)
            const Positioned.fill(child: AppStartScreen()),
          if (showUnstableConnectionBanner)
            UnstableConnectionBanner(onOpenOffline: widget.onOpenOffline),
        ],
      ),
    );
  }
}

int _navIndexForUri(Uri uri) {
  final path = uri.path.endsWith('/') && uri.path.length > 1
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;

  return switch (path) {
    '/me/projects' => 1,
    '/me/records' => 2,
    '/me' => 3,
    _ => 0,
  };
}

String? _navPathForIndex(int index) {
  return switch (index) {
    0 => '/',
    1 => '/me/projects',
    2 => '/me/records',
    3 => '/me',
    _ => null,
  };
}

class UnstableConnectionBanner extends StatelessWidget {
  const UnstableConnectionBanner({
    this.onOpenOffline,
    super.key,
  });

  final VoidCallback? onOpenOffline;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: const Color(0xFFFFF8E1),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '연결이 불안정합니다.',
                        style: TextStyle(
                          color: Color(0xFF4E3D00),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '페이지가 느리면 저장된 코스를 볼 수 있습니다.',
                        style: TextStyle(
                          color: Color(0xFF5D4A00),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onOpenOffline != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onOpenOffline,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF333333),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('저장된 코스 보기'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnlineWebViewFrame extends StatelessWidget {
  const OnlineWebViewFrame({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: child,
    );
  }
}
