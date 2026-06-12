import 'kakao_native_login_service.dart';
import 'native_social_login_service.dart';
import 'naver_native_login_service.dart';

class GraniteNativeSocialLoginService implements NativeSocialLoginService {
  const GraniteNativeSocialLoginService({
    this.kakaoLoginService = const KakaoNativeLoginService(),
    this.naverLoginService = const NaverNativeLoginService(),
  });

  final NativeSocialLoginService kakaoLoginService;
  final NativeSocialLoginService naverLoginService;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) {
    if (request.provider == 'kakao') {
      return kakaoLoginService.login(request);
    }

    if (request.provider == 'naver') {
      return naverLoginService.login(request);
    }

    throw NativeSocialLoginException(
      'Unsupported native login provider: ${request.provider}.',
    );
  }
}
