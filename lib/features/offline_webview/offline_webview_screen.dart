import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/widgets/app_start_screen.dart';
import '../../shared/widgets/granite_logo.dart';

typedef RetryOnlineCallback = Future<bool> Function();

typedef OfflineWebViewBuilder = Widget Function(
  BuildContext context,
  String assetPath,
  RetryOnlineCallback? onRetryOnline,
);

class OfflineWebViewScreen extends StatefulWidget {
  const OfflineWebViewScreen({
    this.assetPath = AppConstants.offlineWebAssetPath,
    this.onRetryOnline,
    this.webViewBuilder,
    super.key,
  });

  final String assetPath;
  final RetryOnlineCallback? onRetryOnline;
  final OfflineWebViewBuilder? webViewBuilder;

  @override
  State<OfflineWebViewScreen> createState() => _OfflineWebViewScreenState();
}

class _OfflineWebViewScreenState extends State<OfflineWebViewScreen> {
  WebViewController? _controller;
  var _isInitialPageLoaded = false;
  var _isRetryingOnline = false;

  @override
  void initState() {
    super.initState();

    if (widget.webViewBuilder == null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setOverScrollMode(WebViewOverScrollMode.never)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => _handleInitialPageLoaded(),
          ),
        );

      _controller = controller..loadFlutterAsset(widget.assetPath);
    }
  }

  void _handleInitialPageLoaded() {
    if (!mounted || _isInitialPageLoaded) return;

    setState(() => _isInitialPageLoaded = true);
  }

  Future<void> _retryOnline() async {
    final onRetryOnline = widget.onRetryOnline;
    if (onRetryOnline == null || _isRetryingOnline) return;

    setState(() => _isRetryingOnline = true);
    final didConnect = await onRetryOnline();
    if (!mounted) return;

    setState(() => _isRetryingOnline = false);
    if (didConnect) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('아직 온라인 연결을 확인할 수 없습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.webViewBuilder;
    if (builder != null) {
      return builder(context, widget.assetPath, widget.onRetryOnline);
    }

    return Scaffold(
      body: Column(
        children: [
          OfflineNativeHeader(
            isRetrying: _isRetryingOnline,
            onRetryOnline: widget.onRetryOnline == null ? null : _retryOnline,
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (!_isInitialPageLoaded)
                  const Positioned.fill(child: AppStartScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OfflineNativeHeader extends StatelessWidget {
  const OfflineNativeHeader({
    required this.isRetrying,
    required this.onRetryOnline,
    super.key,
  });

  final bool isRetrying;
  final VoidCallback? onRetryOnline;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('offline-native-header'),
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Image.asset(
                  GraniteLogo.assetName,
                  height: 28,
                  fit: BoxFit.contain,
                  semanticLabel: 'Granite',
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF222420),
                    border: Border.all(color: const Color(0xFF4C5048)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '오프라인',
                      style: TextStyle(
                        color: Color(0xFFF2F2F2),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('offline-retry-button'),
                  tooltip: '온라인으로 다시 시도',
                  icon: isRetrying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFF2F2F2),
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  color: const Color(0xFFF2F2F2),
                  disabledColor: const Color(0xFF858982),
                  onPressed: onRetryOnline == null || isRetrying
                      ? null
                      : onRetryOnline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
