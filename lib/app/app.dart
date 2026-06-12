import 'package:flutter/material.dart';

import '../features/auth/app_auth_repository.dart';
import '../features/auth/auth_gate.dart';
import '../features/auth/native_auth_service.dart';

class GraniteApp extends StatelessWidget {
  GraniteApp({
    required this.initialUrl,
    AppAuthRepository? authRepository,
    this.nativeAuthService = const DevNativeAuthService(),
    this.webViewBuilder,
    super.key,
  }) : authRepository = authRepository ?? MemoryAppAuthRepository();

  final Uri initialUrl;
  final AppAuthRepository authRepository;
  final NativeAuthService nativeAuthService;
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
        webViewBuilder: webViewBuilder,
      ),
    );
  }
}
