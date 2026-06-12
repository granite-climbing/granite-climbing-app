import 'native_social_login_channel.dart';
import 'native_social_login_service.dart';

class NaverNativeLoginService implements NativeSocialLoginService {
  const NaverNativeLoginService({
    this.channel = const NativeSocialLoginChannel(),
  });

  final NativeSocialLoginChannel channel;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    if (request.provider != 'naver') {
      throw NativeSocialLoginException(
        'Unsupported native login provider: ${request.provider}.',
      );
    }

    final accessToken = await channel.loginWithNaver();
    return NativeSocialLoginResult(
      provider: 'naver',
      accessToken: accessToken,
    );
  }
}
