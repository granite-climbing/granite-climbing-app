import 'dart:async';

import 'package:flutter/material.dart';

import '../core/connectivity/network_status.dart';
import '../core/connectivity/network_status_service.dart';
import '../features/offline_webview/offline_webview_screen.dart';
import '../features/webview/online_webview_screen.dart';
import '../shared/widgets/app_start_screen.dart';

class GraniteApp extends StatelessWidget {
  const GraniteApp({
    required this.initialUrl,
    required this.networkStatusService,
    this.startupDelay = Duration.zero,
    this.webViewFirstLoadWarningDelay = const Duration(seconds: 8),
    this.webViewBuilder,
    this.offlineWebViewBuilder,
    super.key,
  });

  final Uri initialUrl;
  final NetworkStatusService networkStatusService;
  final Duration startupDelay;
  final Duration webViewFirstLoadWarningDelay;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;
  final OfflineWebViewBuilder? offlineWebViewBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Granite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F312D)),
        useMaterial3: true,
      ),
      home: NetworkGate(
        initialUrl: initialUrl,
        networkStatusService: networkStatusService,
        startupDelay: startupDelay,
        webViewFirstLoadWarningDelay: webViewFirstLoadWarningDelay,
        webViewBuilder: webViewBuilder,
        offlineWebViewBuilder: offlineWebViewBuilder,
      ),
    );
  }
}

class NetworkGate extends StatefulWidget {
  const NetworkGate({
    required this.initialUrl,
    required this.networkStatusService,
    this.startupDelay = Duration.zero,
    this.webViewFirstLoadWarningDelay = const Duration(seconds: 8),
    this.webViewBuilder,
    this.offlineWebViewBuilder,
    super.key,
  });

  final Uri initialUrl;
  final NetworkStatusService networkStatusService;
  final Duration startupDelay;
  final Duration webViewFirstLoadWarningDelay;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;
  final OfflineWebViewBuilder? offlineWebViewBuilder;

  @override
  State<NetworkGate> createState() => _NetworkGateState();
}

class _NetworkGateState extends State<NetworkGate> {
  NetworkStatus? _status;
  StreamSubscription<NetworkStatus>? _subscription;
  var _startupDelayDone = false;
  NetworkStatus? _pendingStatus;
  var _hasWatchedStatus = false;

  @override
  void initState() {
    super.initState();
    _completeStartupDelay();
    _loadInitialStatus();
    _watchNetworkStatus();
  }

  Future<void> _completeStartupDelay() async {
    if (widget.startupDelay > Duration.zero) {
      await Future<void>.delayed(widget.startupDelay);
    }
    if (!mounted) return;

    setState(() {
      _startupDelayDone = true;
      final pendingStatus = _pendingStatus;
      if (pendingStatus != null) {
        _status = pendingStatus;
        _pendingStatus = null;
      }
    });
  }

  Future<void> _loadInitialStatus() async {
    NetworkStatus status;
    try {
      status = await widget.networkStatusService.currentStatus();
    } catch (_) {
      status = NetworkStatus.blocked;
    }

    if (_hasWatchedStatus) return;
    _setStatusWhenReady(status);
  }

  void _watchNetworkStatus() {
    try {
      _subscription = widget.networkStatusService.watchStatus().listen(
        (status) {
          _hasWatchedStatus = true;
          _setStatusWhenReady(status);
        },
        onError: (_) {
          _hasWatchedStatus = true;
          _setStatusWhenReady(NetworkStatus.blocked);
        },
      );
    } catch (_) {
      _hasWatchedStatus = true;
      _setStatusWhenReady(NetworkStatus.blocked);
    }
  }

  void _setStatusWhenReady(NetworkStatus status) {
    if (!mounted) return;

    if (!_startupDelayDone) {
      _pendingStatus = status;
      return;
    }

    setState(() => _status = status);
  }

  Future<bool> _retryOnline() async {
    NetworkStatus status;
    try {
      status = await widget.networkStatusService.currentStatus();
    } catch (_) {
      status = NetworkStatus.blocked;
    }

    if (!mounted) return false;

    _setStatusWhenReady(status);
    return status == NetworkStatus.online || status == NetworkStatus.slow;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    if (status == null) {
      return const AppStartScreen();
    }

    if (status == NetworkStatus.online || status == NetworkStatus.slow) {
      final webViewBuilder = widget.webViewBuilder;
      return OnlineWebViewScreen(
        initialUrl: widget.initialUrl,
        showUnstableConnectionBanner: status == NetworkStatus.slow,
        firstLoadWarningDelay: widget.webViewFirstLoadWarningDelay,
        onOpenOffline: () => _setStatusWhenReady(NetworkStatus.offline),
        webViewBuilder: webViewBuilder,
      );
    }

    return OfflineWebViewScreen(
      onRetryOnline: _retryOnline,
      webViewBuilder: widget.offlineWebViewBuilder,
    );
  }
}
