import 'native_social_login_service.dart';
import 'naver_native_login_client.dart';

class NaverNativeLoginService implements NativeSocialLoginService {
  const NaverNativeLoginService({
    this.client = const NaverLoginSdkClient(),
  });

  final NaverNativeLoginClient client;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    if (request.provider != 'naver') {
      throw NativeSocialLoginException(
        'Unsupported native login provider: ${request.provider}.',
      );
    }

    final loggedIn = await client.login();
    if (!loggedIn) {
      throw const NativeSocialLoginCanceledException();
    }

    final accessToken = await client.getAccessToken();
    if (accessToken.trim().isEmpty) {
      throw const NativeSocialLoginException(
        'Naver native login did not return an access token.',
      );
    }

    return NativeSocialLoginResult(
      provider: 'naver',
      accessToken: accessToken,
    );
  }
}
