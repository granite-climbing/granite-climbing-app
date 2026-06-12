import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/native_auth_exchange_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('exchanges a native access token for a consume URL', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;

      return http.Response(
        jsonEncode({
          'handoffCode': 'handoff-1',
          'returnTo': '/me',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = NativeAuthExchangeService(
      client: client,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

    final result = await service.exchange(
      const NativeAuthExchangeRequest(
        provider: 'kakao',
        accessToken: 'token-1',
        returnTo: '/me',
      ),
    );

    expect(capturedRequest?.method, 'POST');
    expect(
      capturedRequest?.url.toString(),
      'https://granite.kr/api/auth/native/exchange',
    );
    expect(
      jsonDecode(capturedRequest!.body),
      {
        'provider': 'kakao',
        'accessToken': 'token-1',
        'returnTo': '/me',
      },
    );
    expect(
      result.consumeUrl.toString(),
      'https://granite.kr/api/auth/native/consume?code=handoff-1',
    );
  });

  test('includes a native id token when exchanging provider credentials',
      () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;

      return http.Response(
        jsonEncode({
          'handoffCode': 'handoff-1',
          'returnTo': '/me',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = NativeAuthExchangeService(
      client: client,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

    await service.exchange(
      const NativeAuthExchangeRequest(
        provider: 'google',
        accessToken: '',
        idToken: 'google-id-token',
        returnTo: '/me',
      ),
    );

    expect(
      jsonDecode(capturedRequest!.body),
      {
        'provider': 'google',
        'accessToken': '',
        'idToken': 'google-id-token',
        'returnTo': '/me',
      },
    );
  });

  test('throws when the exchange endpoint rejects the provider token',
      () async {
    final service = NativeAuthExchangeService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'native_profile_failed'}),
          401,
        ),
      ),
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

    await expectLater(
      service.exchange(
        const NativeAuthExchangeRequest(
          provider: 'kakao',
          accessToken: 'bad-token',
          returnTo: '/me',
        ),
      ),
      throwsA(isA<NativeAuthExchangeException>()),
    );
  });
}
