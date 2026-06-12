import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/google_native_login_service.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';

void main() {
  test('returns a Google native login result with an id token', () async {
    final service = GoogleNativeLoginService(
      client: FakeGoogleLoginClient(
        tokens: const GoogleLoginTokens(
          accessToken: 'google-access-token',
          idToken: 'google-id-token',
        ),
      ),
    );

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'google', returnTo: '/me'),
    );

    expect(result.provider, 'google');
    expect(result.accessToken, 'google-access-token');
    expect(result.idToken, 'google-id-token');
  });

  test('rejects non-Google native login requests', () async {
    final service = GoogleNativeLoginService(
      client: FakeGoogleLoginClient(
        tokens: const GoogleLoginTokens(idToken: 'google-id-token'),
      ),
    );

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'apple')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });

  test('throws when Google does not return a usable token', () async {
    final service = GoogleNativeLoginService(
      client: FakeGoogleLoginClient(tokens: const GoogleLoginTokens()),
    );

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'google')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });
}

class FakeGoogleLoginClient implements GoogleLoginClient {
  FakeGoogleLoginClient({required this.tokens});

  final GoogleLoginTokens tokens;

  @override
  Future<GoogleLoginTokens> login() async => tokens;
}
