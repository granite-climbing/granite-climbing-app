import 'package:flutter/material.dart';

import '../features/auth/app_auth_repository.dart';
import '../features/auth/auth_gate.dart';
import '../features/auth/native_auth_service.dart';
import '../features/auth/session_handoff_service.dart';

class GraniteApp extends StatelessWidget {
  GraniteApp({
    required this.initialUrl,
    AppAuthRepository? authRepository,
    this.nativeAuthService = const DevNativeAuthService(),
    this.sessionHandoffService = const DevSessionHandoffService(),
    this.webViewBuilder,
    super.key,
  }) : authRepository = authRepository ?? SecureAppAuthRepository();

  final Uri initialUrl;
  final AppAuthRepository authRepository;
  final NativeAuthService nativeAuthService;
  final SessionHandoffService sessionHandoffService;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GRANITE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F312D)),
        useMaterial3: true,
      ),
      home: AuthGate(
        initialUrl: initialUrl,
        authRepository: authRepository,
        nativeAuthService: nativeAuthService,
        sessionHandoffService: sessionHandoffService,
        webViewBuilder: webViewBuilder,
      ),
    );
  }
}
