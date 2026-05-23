class NativeLoginRequest {
  const NativeLoginRequest({
    this.returnTo,
  });

  final String? returnTo;
}

class NativeLoginStart {
  const NativeLoginStart({
    this.provider,
  });

  final String? provider;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      if (provider != null) 'provider': provider,
    };
  }
}

abstract interface class NativeAuthService {
  Future<NativeLoginStart> startLogin(NativeLoginRequest request);

  Future<void> logout();
}

class DevNativeAuthService implements NativeAuthService {
  const DevNativeAuthService();

  @override
  Future<NativeLoginStart> startLogin(NativeLoginRequest request) async {
    return const NativeLoginStart(provider: 'native');
  }

  @override
  Future<void> logout() async {}
}
