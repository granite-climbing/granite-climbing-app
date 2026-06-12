class NativeSocialLoginRequest {
  const NativeSocialLoginRequest({
    required this.provider,
    this.returnTo,
  });

  final String provider;
  final String? returnTo;
}

class NativeSocialLoginResult {
  const NativeSocialLoginResult({
    required this.provider,
    required this.accessToken,
  });

  final String provider;
  final String accessToken;
}

abstract interface class NativeSocialLoginService {
  Future<NativeSocialLoginResult> login(NativeSocialLoginRequest request);
}

class NativeSocialLoginException implements Exception {
  const NativeSocialLoginException(this.message);

  final String message;

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
