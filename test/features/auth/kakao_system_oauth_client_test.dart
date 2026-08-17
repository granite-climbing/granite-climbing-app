import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/kakao_system_oauth_client.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';

void main() {
  test('opens the iOS Kakao REST OAuth URL and returns its handoff', () async {
    String? capturedUrl;
    String? capturedCallbackScheme;
    final bytes = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final verifier = base64Url.encode(bytes).replaceAll('=', '');
    final expectedChallenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final client = KakaoSystemOAuthClient(
      webBaseUrl: Uri.parse('https://granite.kr/app?old=query#old-fragment'),
      secureRandomBytes: (_) => bytes,
      authenticate: ({required url, required callbackUrlScheme}) async {
        capturedUrl = url;
        capturedCallbackScheme = callbackUrlScheme;
        return 'graniteclimbing://oauth/kakao?handoff=encrypted-handoff';
      },
    );

    final result = await client.login(returnTo: '/routes/route-1');
    final authorizationUrl = Uri.parse(capturedUrl!);

    expect(capturedCallbackScheme, 'graniteclimbing');
    expect(authorizationUrl.fragment, isEmpty);
    expect(
      '${authorizationUrl.scheme}://${authorizationUrl.host}${authorizationUrl.path}',
      'https://granite.kr/api/auth/start/kakao',
    );
    expect(authorizationUrl.queryParameters, {
      'returnTo': '/routes/route-1',
      'native_system_auth': 'ios',
      'handoff_challenge': expectedChallenge,
    });
    expect(result.token, 'encrypted-handoff');
    expect(result.verifier, verifier);
  });

  test('falls back to a safe return path before opening OAuth', () async {
    Uri? authorizationUrl;
    final client = KakaoSystemOAuthClient(
      secureRandomBytes: (_) => Uint8List(32),
      authenticate: ({required url, required callbackUrlScheme}) async {
        authorizationUrl = Uri.parse(url);
        return 'graniteclimbing://oauth/kakao?handoff=encrypted-handoff';
      },
    );

    await client.login(returnTo: '//attacker.example');

    expect(authorizationUrl!.queryParameters['returnTo'], '/me');
  });

  test('maps provider cancellation to native login cancellation', () async {
    final client = KakaoSystemOAuthClient(
      secureRandomBytes: (_) => Uint8List(32),
      authenticate: ({required url, required callbackUrlScheme}) async {
        return 'graniteclimbing://oauth/kakao?error=access_denied';
      },
    );

    await expectLater(
      client.login(returnTo: '/me'),
      throwsA(isA<NativeSocialLoginCanceledException>()),
    );
  });

  test('maps a dismissed iOS authentication sheet to cancellation', () async {
    final client = KakaoSystemOAuthClient(
      secureRandomBytes: (_) => Uint8List(32),
      authenticate: ({required url, required callbackUrlScheme}) async {
        throw PlatformException(code: 'CANCELED');
      },
    );

    await expectLater(
      client.login(returnTo: '/me'),
      throwsA(isA<NativeSocialLoginCanceledException>()),
    );
  });

  test('rejects callbacks outside the fixed Granite Kakao URL', () async {
    final client = KakaoSystemOAuthClient(
      secureRandomBytes: (_) => Uint8List(32),
      authenticate: ({required url, required callbackUrlScheme}) async {
        return 'graniteclimbing://attacker/kakao?handoff=encrypted-handoff';
      },
    );

    await expectLater(
      client.login(returnTo: '/me'),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });
}
