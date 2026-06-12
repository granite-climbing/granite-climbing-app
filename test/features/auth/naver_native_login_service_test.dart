import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_channel.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';
import 'package:granite_climbing_app/features/auth/naver_native_login_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel(NativeSocialLoginChannel.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  test('provider naver invokes the native login method channel', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return {
        'accessToken': 'naver-token-1',
      };
    });
    const service = NaverNativeLoginService();

    final result = await service.login(
      const NativeSocialLoginRequest(provider: 'naver', returnTo: '/me'),
    );

    expect(calls.single.method, 'loginWithNaver');
    expect(result.provider, 'naver');
    expect(result.accessToken, 'naver-token-1');
  });

  test('maps native not_configured errors to native login exceptions',
      () async {
    messenger.setMockMethodCallHandler(methodChannel, (_) async {
      throw PlatformException(
        code: 'not_configured',
        message: 'Naver native login is not configured.',
      );
    });
    const service = NaverNativeLoginService();

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'naver')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });

  test('rejects non-Naver native login requests', () async {
    const service = NaverNativeLoginService();

    await expectLater(
      service.login(const NativeSocialLoginRequest(provider: 'kakao')),
      throwsA(isA<NativeSocialLoginException>()),
    );
  });
}
