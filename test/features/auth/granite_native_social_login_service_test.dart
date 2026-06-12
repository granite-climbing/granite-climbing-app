import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/granite_native_social_login_service.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';

void main() {
  test('routes Naver requests to the Naver native login service', () async {
    final kakao = RecordingNativeSocialLoginService('kakao', 'kakao-token');
    final naver = RecordingNativeSocialLoginService('naver', 'naver-token');
    final service = GraniteNativeSocialLoginService(
      kakaoLoginService: kakao,
      naverLoginService: naver,
    );

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'naver', returnTo: '/me'),
    );

    expect(result.provider, 'naver');
    expect(result.accessToken, 'naver-token');
    expect(kakao.requests, isEmpty);
    expect(naver.requests.single.provider, 'naver');
  });

  test('routes Kakao requests to the Kakao native login service', () async {
    final kakao = RecordingNativeSocialLoginService('kakao', 'kakao-token');
    final naver = RecordingNativeSocialLoginService('naver', 'naver-token');
    final service = GraniteNativeSocialLoginService(
      kakaoLoginService: kakao,
      naverLoginService: naver,
    );

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'kakao', returnTo: '/me'),
    );

    expect(result.provider, 'kakao');
    expect(result.accessToken, 'kakao-token');
    expect(kakao.requests.single.provider, 'kakao');
    expect(naver.requests, isEmpty);
  });

  test('routes Google requests to the Google native login service', () async {
    final google = RecordingNativeSocialLoginService(
      'google',
      '',
      idToken: 'google-id-token',
    );
    final service = GraniteNativeSocialLoginService(
      googleLoginService: google,
    );

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'google', returnTo: '/me'),
    );

    expect(result.provider, 'google');
    expect(result.idToken, 'google-id-token');
    expect(google.requests.single.provider, 'google');
  });

  test('routes Apple requests to the Apple native login service', () async {
    final apple = RecordingNativeSocialLoginService(
      'apple',
      '',
      idToken: 'apple-id-token',
    );
    final service = GraniteNativeSocialLoginService(
      appleLoginService: apple,
    );

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'apple', returnTo: '/me'),
    );

    expect(result.provider, 'apple');
    expect(result.idToken, 'apple-id-token');
    expect(apple.requests.single.provider, 'apple');
  });
}

class RecordingNativeSocialLoginService implements NativeSocialLoginService {
  RecordingNativeSocialLoginService(
    this.provider,
    this.accessToken, {
    this.idToken,
  });

  final String provider;
  final String accessToken;
  final String? idToken;
  final List<NativeSocialLoginRequest> requests = [];

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    requests.add(request);
    return NativeSocialLoginResult(
      provider: provider,
      accessToken: accessToken,
      idToken: idToken,
    );
  }
}
