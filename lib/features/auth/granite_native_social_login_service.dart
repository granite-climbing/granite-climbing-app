import 'apple_native_login_service.dart';
import 'google_native_login_service.dart';
import 'kakao_native_login_service.dart';
import 'native_social_login_service.dart';
import 'naver_native_login_service.dart';

class GraniteNativeSocialLoginService implements NativeSocialLoginService {
  const GraniteNativeSocialLoginService({
    this.kakaoLoginService = const KakaoNativeLoginService(),
    this.naverLoginService = const NaverNativeLoginService(),
    this.googleLoginService = const GoogleNativeLoginService(),
    this.appleLoginService = const AppleNativeLoginService(),
  });

  final NativeSocialLoginService kakaoLoginService;
  final NativeSocialLoginService naverLoginService;
  final NativeSocialLoginService googleLoginService;
  final NativeSocialLoginService appleLoginService;

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

    if (request.provider == 'google') {
      return googleLoginService.login(request);
    }

    if (request.provider == 'apple') {
      return appleLoginService.login(request);
    }

    throw NativeSocialLoginException(
      'Unsupported native login provider: ${request.provider}.',
    );
  }
}
