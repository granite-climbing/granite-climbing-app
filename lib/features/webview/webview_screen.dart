import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/bridge/bridge_controller.dart';
import '../../data/bridge/bridge_handler.dart';
import '../../data/bridge/handlers/app_bridge_handler.dart';
import '../../data/bridge/handlers/auth_bridge_handler.dart';
import '../../data/bridge/handlers/navigation_bridge_handler.dart';
import '../../data/bridge/handlers/share_bridge_handler.dart';
import '../../shared/widgets/app_start_screen.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    required this.initialUrl,
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
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;
  final List<BridgeHandler> bridgeHandlers;

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
    _bridgeController = BridgeController(handlers: widget.bridgeHandlers);

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

  void _handleInitialPageLoaded() {
    if (!mounted || _isInitialPageLoaded) return;

    setState(() => _isInitialPageLoaded = true);
  }

  void _handlePageFinished(String url) {
    _handleInitialPageLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.webViewBuilder;
    final child = builder == null
        ? WebViewFrame(
            child: WebViewWidget(controller: _controller!),
          )
        : builder(context, widget.initialUrl);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          if (builder == null && !_isInitialPageLoaded)
            const Positioned.fill(child: AppStartScreen()),
        ],
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
