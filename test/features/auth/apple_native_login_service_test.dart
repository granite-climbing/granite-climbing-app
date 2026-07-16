import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/apple_native_login_service.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';

void main() {
  test('returns an Apple native login result with an identity token', () async {
    final service = AppleNativeLoginService(
      client: FakeAppleLoginClient(
        credential: const AppleLoginCredential(
          identityToken: 'apple-id-token',
          authorizationCode: 'apple-authorization-code',
        ),
      ),
    );

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'apple', returnTo: '/me'),
    );

    expect(result.provider, 'apple');
    expect(result.accessToken, '');
    expect(result.idToken, 'apple-id-token');
  });

  test('rejects non-Apple native login requests', () async {
    final service = AppleNativeLoginService(
      client: FakeAppleLoginClient(
        credential: const AppleLoginCredential(identityToken: 'apple-id-token'),
      ),
    );

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'google')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });

  test('throws when Apple does not return an identity token', () async {
    final service = AppleNativeLoginService(
      client: FakeAppleLoginClient(
        credential: const AppleLoginCredential(authorizationCode: 'code-only'),
      ),
    );

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'apple')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });

  test('extracts only HTTP-like Apple provider status codes', () {
    expect(appleProviderHttpStatus('Apple callback returned HTTP 405.'), 405);
    expect(appleProviderHttpStatus('request error 99'), isNull);
    expect(appleProviderHttpStatus('no provider status'), isNull);
  });
}

class FakeAppleLoginClient implements AppleLoginClient {
  FakeAppleLoginClient({required this.credential});

  final AppleLoginCredential credential;

  @override
  Future<AppleLoginCredential> login() async => credential;
}
