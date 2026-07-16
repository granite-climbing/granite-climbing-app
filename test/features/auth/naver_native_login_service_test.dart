import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';
import 'package:granite_climbing_app/features/auth/naver_native_login_client.dart';
import 'package:granite_climbing_app/features/auth/naver_native_login_service.dart';

class FakeNaverNativeLoginClient implements NaverNativeLoginClient {
  FakeNaverNativeLoginClient({
    this.loginResult = true,
    this.accessToken = 'naver-token-1',
  });

  final bool loginResult;
  final String accessToken;
  var loginCalls = 0;
  var accessTokenReads = 0;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<String> getAccessToken() async {
    accessTokenReads += 1;
    return accessToken;
  }

  @override
  Future<bool> login() async {
    loginCalls += 1;
    return loginResult;
  }
}

void main() {
  test('returns the Naver SDK access token after native app login', () async {
    final client = FakeNaverNativeLoginClient();
    final service = NaverNativeLoginService(client: client);

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'naver', returnTo: '/me'),
    );

    expect(client.loginCalls, 1);
    expect(result.provider, 'naver');
    expect(result.accessToken, 'naver-token-1');
  });

  test('maps a cancelled Naver SDK login to a cancellation exception',
      () async {
    final client = FakeNaverNativeLoginClient(loginResult: false);
    final service = NaverNativeLoginService(client: client);

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'naver')),
      throwsA(isA<NativeSocialLoginCanceledException>()),
    );

    expect(client.accessTokenReads, 0);
  });

  test('rejects an empty access token from the Naver SDK', () async {
    final client = FakeNaverNativeLoginClient(accessToken: '  ');
    final service = NaverNativeLoginService(client: client);

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'naver')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });

  test('rejects non-Naver native login requests', () async {
    const service = NaverNativeLoginService();

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'kakao')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });
}
