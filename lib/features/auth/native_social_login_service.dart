enum NativeSocialLoginMode {
  talkPreferred,
  account,
}

class NativeSocialLoginRequest {
  const NativeSocialLoginRequest({
    required this.provider,
    this.returnTo,
    this.loginMode = NativeSocialLoginMode.talkPreferred,
  });

  final String provider;
  final String? returnTo;
  final NativeSocialLoginMode loginMode;
}

class NativeSocialLoginResult {
  const NativeSocialLoginResult({
    required this.provider,
    this.accessToken = '',
    this.idToken,
    this.browserSessionHandoff,
  });

  final String provider;
  final String accessToken;
  final String? idToken;
  final NativeBrowserSessionHandoff? browserSessionHandoff;
}

class NativeBrowserSessionHandoff {
  const NativeBrowserSessionHandoff({
    required this.token,
    required this.verifier,
  });

  final String token;
  final String verifier;
}

abstract interface class NativeSocialLoginService {
  Future<NativeSocialLoginResult> login(NativeSocialLoginRequest request);
}

class NativeSocialLoginException implements Exception {
  const NativeSocialLoginException(
    this.message, {
    this.diagnosticCode = 'native-login-failed',
    this.providerStatus,
  });

  final String message;
  final String diagnosticCode;
  final int? providerStatus;

  @override
  String toString() {
    return 'NativeSocialLoginException: $message';
  }
}

class NativeSocialLoginCanceledException implements Exception {
  const NativeSocialLoginCanceledException();
}

class DevNativeSocialLoginService implements NativeSocialLoginService {
  const DevNativeSocialLoginService();

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    throw const NativeSocialLoginException(
      'Native social login is not configured.',
    );
  }
}
