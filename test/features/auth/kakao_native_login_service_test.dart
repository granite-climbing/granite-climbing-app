import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/kakao_native_login_service.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

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

  test('uses forced Kakao Account login for account mode', () async {
    final client = FakeKakaoLoginClient(
      kakaoTalkInstalled: true,
      talkAccessToken: 'talk-token',
      accountAccessToken: 'account-token',
    );
    final service = KakaoNativeLoginService(client: client);

    final result = await service.login(
      const NativeSocialLoginRequest(
        provider: 'kakao',
        returnTo: '/me',
        loginMode: NativeSocialLoginMode.account,
      ),
    );

    expect(result.accessToken, 'account-token');
    expect(client.installedCheckCount, 0);
    expect(client.talkLoginCount, 0);
    expect(client.accountLoginCount, 1);
    expect(client.forceAccountLoginValues, [true]);
  });

  test('maps a cancelled Kakao Account login to cancellation', () async {
    final service = KakaoNativeLoginService(
      client: FakeKakaoLoginClient(
        kakaoTalkInstalled: true,
        talkAccessToken: 'talk-token',
        accountAccessToken: 'account-token',
        accountError: kakao.KakaoClientException(
          kakao.ClientErrorCause.cancelled,
          'cancelled',
        ),
      ),
    );

    await expectLater(
      service.login(
        const NativeSocialLoginRequest(
          provider: 'kakao',
          loginMode: NativeSocialLoginMode.account,
        ),
      ),
      throwsA(isA<NativeSocialLoginCanceledException>()),
    );
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
    this.accountError,
  });

  final bool kakaoTalkInstalled;
  final String talkAccessToken;
  final String accountAccessToken;
  final bool throwFromTalk;
  final Object? accountError;
  var installedCheckCount = 0;
  var talkLoginCount = 0;
  var accountLoginCount = 0;
  final List<bool> forceAccountLoginValues = [];

  @override
  Future<bool> isKakaoTalkInstalled() async {
    installedCheckCount += 1;
    return kakaoTalkInstalled;
  }

  @override
  Future<String> loginWithKakaoTalk() async {
    talkLoginCount += 1;
    if (throwFromTalk) {
      throw Exception('Talk login failed.');
    }

    return talkAccessToken;
  }

  @override
  Future<String> loginWithKakaoAccount({bool forceLogin = false}) async {
    accountLoginCount += 1;
    forceAccountLoginValues.add(forceLogin);
    final error = accountError;
    if (error != null) {
      throw error;
    }

    return accountAccessToken;
  }
}
