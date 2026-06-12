import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'native_social_login_service.dart';

abstract interface class KakaoLoginClient {
  Future<bool> isKakaoTalkInstalled();

  Future<String> loginWithKakaoTalk();

  Future<String> loginWithKakaoAccount();
}

class KakaoNativeLoginService implements NativeSocialLoginService {
  const KakaoNativeLoginService({
    this.client = const SdkKakaoLoginClient(),
  });

  final KakaoLoginClient client;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    if (request.provider != 'kakao') {
      throw NativeSocialLoginException(
        'Unsupported native login provider: ${request.provider}.',
      );
    }

    final accessToken = await _login();
    return NativeSocialLoginResult(
      provider: 'kakao',
      accessToken: accessToken,
    );
  }

  Future<String> _login() async {
    if (!await client.isKakaoTalkInstalled()) {
      return client.loginWithKakaoAccount();
    }

    try {
      return await client.loginWithKakaoTalk();
    } catch (_) {
      return client.loginWithKakaoAccount();
    }
  }
}

class SdkKakaoLoginClient implements KakaoLoginClient {
  const SdkKakaoLoginClient();

  @override
  Future<bool> isKakaoTalkInstalled() {
    return kakao.isKakaoTalkInstalled();
  }

  @override
  Future<String> loginWithKakaoTalk() async {
    final token = await kakao.UserApi.instance.loginWithKakaoTalk();
    return token.accessToken;
  }

  @override
  Future<String> loginWithKakaoAccount() async {
    final token = await kakao.UserApi.instance.loginWithKakaoAccount();
    return token.accessToken;
  }
}
