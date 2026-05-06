import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/widgets/app_start_screen.dart';

class OnlineWebViewScreen extends StatefulWidget {
  const OnlineWebViewScreen({
    required this.initialUrl,
    this.showUnstableConnectionBanner = false,
    this.firstLoadWarningDelay = const Duration(seconds: 8),
    this.onOpenOffline,
    this.webViewBuilder,
    super.key,
  });

  final Uri initialUrl;
  final bool showUnstableConnectionBanner;
  final Duration firstLoadWarningDelay;
  final VoidCallback? onOpenOffline;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;

  @override
  State<OnlineWebViewScreen> createState() => _OnlineWebViewScreenState();
}

class _OnlineWebViewScreenState extends State<OnlineWebViewScreen> {
  WebViewController? _controller;
  Timer? _firstLoadWarningTimer;
  var _isInitialPageLoaded = false;
  var _isFirstLoadSlow = false;

  @override
  void initState() {
    super.initState();
    _startFirstLoadWarningTimer();

    if (widget.webViewBuilder == null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setOverScrollMode(WebViewOverScrollMode.never)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => _handleInitialPageLoaded(),
          ),
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
    if (builder != null) {
      return Stack(
        children: [
          Positioned.fill(child: builder(context, widget.initialUrl)),
          if (showUnstableConnectionBanner)
            UnstableConnectionBanner(onOpenOffline: widget.onOpenOffline),
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          OnlineWebViewFrame(
            child: WebViewWidget(controller: _controller!),
          ),
          if (!_isInitialPageLoaded)
            const Positioned.fill(child: AppStartScreen()),
          if (showUnstableConnectionBanner)
            UnstableConnectionBanner(onOpenOffline: widget.onOpenOffline),
        ],
      ),
    );
  }
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
