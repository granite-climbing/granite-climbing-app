import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/bridge/bridge_controller.dart';
import '../../data/bridge/bridge_handler.dart';
import '../../data/bridge/handlers/app_bridge_handler.dart';
import '../../data/bridge/handlers/auth_bridge_handler.dart';
import '../../data/bridge/handlers/navigation_bridge_handler.dart';
import '../../data/bridge/handlers/navigation_map_bridge_handler.dart';
import '../../data/bridge/handlers/share_bridge_handler.dart';
import '../../features/navigation/native_map_service.dart';
import '../../shared/widgets/app_start_screen.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    required this.initialUrl,
    this.webViewBuilder,
    this.bridgeHandlers,
    this.nativeMapService = const NativeMapService(),
    super.key,
  });

  final Uri initialUrl;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;
  final List<BridgeHandler>? bridgeHandlers;
  final NativeMapService nativeMapService;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final BridgeController _bridgeController;
  WebViewController? _controller;
  var _isInitialPageLoaded = false;

  @override
  void initState() {
    super.initState();
    _bridgeController = BridgeController(
      handlers: widget.bridgeHandlers ?? _defaultBridgeHandlers(),
    );

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

  List<BridgeHandler> _defaultBridgeHandlers() {
    return <BridgeHandler>[
      const AppBridgeHandler(),
      const AuthBridgeHandler(),
      const NavigationBridgeHandler(),
      NavigationMapBridgeHandler(openMap: _openPreferredNativeMap),
      const ShareBridgeHandler(),
    ];
  }

  Future<void> _openPreferredNativeMap(NativeMapLocation location) async {
    if (!mounted) return;

    await widget.nativeMapService.openPreferred(location);
  }

  void _handleInitialPageLoaded() {
    if (!mounted || _isInitialPageLoaded) return;

    setState(() => _isInitialPageLoaded = true);
  }

  void _handlePageFinished(String url) {
    _handleInitialPageLoaded();
  }

  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop) return;

    unawaited(_handleSystemBack());
  }

  Future<void> _handleSystemBack() async {
    final controller = _controller;
    if (controller == null) {
      await SystemNavigator.pop();
      return;
    }

    if (await controller.canGoBack()) {
      await controller.goBack();
      return;
    }

    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.webViewBuilder;
    final child = builder == null
        ? WebViewFrame(
            child: WebViewWidget(controller: _controller!),
          )
        : builder(context, widget.initialUrl);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: child),
            if (builder == null && !_isInitialPageLoaded)
              const Positioned.fill(child: AppStartScreen()),
          ],
        ),
      ),
    );
  }
}

class WebViewFrame extends StatelessWidget {
  const WebViewFrame({
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
