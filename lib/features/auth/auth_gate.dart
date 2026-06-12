import 'package:flutter/material.dart';

import '../webview/webview_screen.dart';
import 'app_auth_repository.dart';
import 'app_auth_session.dart';
import 'native_auth_service.dart';
import 'native_login_screen.dart';
import 'session_handoff_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.initialUrl,
    required this.authRepository,
    this.nativeAuthService = const DevNativeAuthService(),
    this.sessionHandoffService = const DevSessionHandoffService(),
    this.webViewBuilder,
    super.key,
  });

  final Uri initialUrl;
  final AppAuthRepository authRepository;
  final NativeAuthService nativeAuthService;
  final SessionHandoffService sessionHandoffService;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppAuthSession? _session;
  Uri? _webUrl;
  late Future<void> _loadSessionFuture;
  var _isStartingLogin = false;

  @override
  void initState() {
    super.initState();
    _loadSessionFuture = _loadSession();
  }

  Future<void> _loadSession() async {
    _session = await widget.authRepository.readSession();
    if (_session == null) {
      return;
    }

    try {
      _webUrl = await _createWebSessionUrl();
    } catch (_) {
      _session = null;
      _webUrl = null;
    }
  }

  Future<void> _startLogin(String provider) async {
    if (_isStartingLogin) return;

    setState(() => _isStartingLogin = true);

    try {
      final start = await widget.nativeAuthService.startLogin(
        NativeLoginRequest(
          providerHint: provider,
          returnTo: widget.initialUrl.path,
          surface: 'flutter-app',
        ),
      );
      final session = AppAuthSession(provider: start.provider ?? provider);
      final webUrl = await _createWebSessionUrl();
      await widget.authRepository.saveSession(session);

      if (!mounted) return;
      setState(() {
        _session = session;
        _webUrl = webUrl;
        _isStartingLogin = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStartingLogin = false);
    }
  }

  Future<Uri> _createWebSessionUrl() async {
    final returnTo = _returnToFromInitialUrl(widget.initialUrl);
    final handoff = await widget.sessionHandoffService.createHandoff(
      SessionHandoffRequest(returnTo: returnTo),
    );

    return _buildAppHandoffUrl(
      baseUrl: widget.initialUrl,
      handoff: handoff,
      fallbackReturnTo: returnTo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadSessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        if (_session == null) {
          return NativeLoginScreen(
            isStarting: _isStartingLogin,
            onProviderSelected: _startLogin,
          );
        }

        final builder = widget.webViewBuilder;
        final webUrl = _webUrl ?? widget.initialUrl;
        if (builder != null) {
          return builder(context, webUrl);
        }

        return WebViewScreen(initialUrl: webUrl);
      },
    );
  }
}

Uri _buildAppHandoffUrl({
  required Uri baseUrl,
  required SessionHandoff handoff,
  required String fallbackReturnTo,
}) {
  return baseUrl.replace(
    path: '/api/auth/app-handoff',
    queryParameters: {
      'code': handoff.handoffCode,
      'returnTo': handoff.returnTo ?? fallbackReturnTo,
    },
    fragment: null,
  );
}

String _returnToFromInitialUrl(Uri url) {
  final path = url.path.isEmpty ? '/' : url.path;
  if (!url.hasQuery) {
    return path;
  }

  return '$path?${url.query}';
}
