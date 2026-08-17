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
    required this.accessToken,
    this.idToken,
  });

  final String provider;
  final String accessToken;
  final String? idToken;
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
