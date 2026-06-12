import 'package:flutter/material.dart';

import '../webview/webview_screen.dart';
import 'app_auth_repository.dart';
import 'app_auth_session.dart';
import 'native_auth_service.dart';
import 'native_login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.initialUrl,
    required this.authRepository,
    this.nativeAuthService = const DevNativeAuthService(),
    this.webViewBuilder,
    super.key,
  });

  final Uri initialUrl;
  final AppAuthRepository authRepository;
  final NativeAuthService nativeAuthService;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppAuthSession? _session;
  late Future<void> _loadSessionFuture;
  var _isStartingLogin = false;

  @override
  void initState() {
    super.initState();
    _loadSessionFuture = _loadSession();
  }

  Future<void> _loadSession() async {
    _session = await widget.authRepository.readSession();
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
      await widget.authRepository.saveSession(session);

      if (!mounted) return;
      setState(() {
        _session = session;
        _isStartingLogin = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStartingLogin = false);
    }
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
        if (builder != null) {
          return builder(context, widget.initialUrl);
        }

        return WebViewScreen(initialUrl: widget.initialUrl);
      },
    );
  }
}
