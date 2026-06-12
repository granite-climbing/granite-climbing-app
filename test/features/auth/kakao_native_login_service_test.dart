import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/kakao_native_login_service.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';

void main() {
  test('uses Kakao Talk login first when Kakao Talk is installed', () async {
    final client = FakeKakaoLoginClient(
      kakaoTalkInstalled: true,
      talkAccessToken: 'talk-token',
      accountAccessToken: 'account-token',
    );
    final service = KakaoNativeLoginService(client: client);

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'kakao', returnTo: '/me'),
    );

    expect(result.provider, 'kakao');
    expect(result.accessToken, 'talk-token');
    expect(client.talkLoginCount, 1);
    expect(client.accountLoginCount, 0);
  });

  test('uses Kakao Account login when Kakao Talk is not installed', () async {
    final client = FakeKakaoLoginClient(
      kakaoTalkInstalled: false,
      talkAccessToken: 'talk-token',
      accountAccessToken: 'account-token',
    );
    final service = KakaoNativeLoginService(client: client);

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'kakao', returnTo: '/me'),
    );

    expect(result.accessToken, 'account-token');
    expect(client.talkLoginCount, 0);
    expect(client.accountLoginCount, 1);
  });

  test('falls back to Kakao Account login when Kakao Talk login fails',
      () async {
    final client = FakeKakaoLoginClient(
      kakaoTalkInstalled: true,
      talkAccessToken: 'talk-token',
      accountAccessToken: 'account-token',
      throwFromTalk: true,
    );
    final service = KakaoNativeLoginService(client: client);

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'kakao', returnTo: '/me'),
    );

    expect(result.accessToken, 'account-token');
    expect(client.talkLoginCount, 1);
    expect(client.accountLoginCount, 1);
  });

  test('rejects non-Kakao native login requests', () async {
    final service = KakaoNativeLoginService(
      client: FakeKakaoLoginClient(
        kakaoTalkInstalled: false,
        talkAccessToken: 'talk-token',
        accountAccessToken: 'account-token',
      ),
    );

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'naver')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });
}

class FakeKakaoLoginClient implements KakaoLoginClient {
  FakeKakaoLoginClient({
    required this.kakaoTalkInstalled,
    required this.talkAccessToken,
    required this.accountAccessToken,
    this.throwFromTalk = false,
  });

  final bool kakaoTalkInstalled;
  final String talkAccessToken;
  final String accountAccessToken;
  final bool throwFromTalk;
  var talkLoginCount = 0;
  var accountLoginCount = 0;

  @override
  Future<bool> isKakaoTalkInstalled() async => kakaoTalkInstalled;

  @override
  Future<String> loginWithKakaoTalk() async {
    talkLoginCount += 1;
    if (throwFromTalk) {
      throw Exception('Talk login failed.');
    }

    return talkAccessToken;
  }

  @override
  Future<String> loginWithKakaoAccount() async {
    accountLoginCount += 1;
    return accountAccessToken;
  }
}
