import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'kakao_system_oauth_client.dart';
import 'native_social_login_service.dart';

abstract interface class KakaoLoginClient {
  Future<bool> isKakaoTalkInstalled();

  Future<String> loginWithKakaoTalk();

  Future<String> loginWithKakaoAccount({bool forceLogin = false});
}

class KakaoNativeLoginService implements NativeSocialLoginService {
  const KakaoNativeLoginService({
    this.client = const SdkKakaoLoginClient(),
    this.systemOAuthClient = const KakaoSystemOAuthClient(),
    this.platform,
  });

  final KakaoLoginClient client;
  final KakaoSystemOAuthClient systemOAuthClient;
  final TargetPlatform? platform;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    if (request.provider != 'kakao') {
      throw NativeSocialLoginException(
        'Unsupported native login provider: ${request.provider}.',
      );
    }

    try {
      if (request.loginMode == NativeSocialLoginMode.account &&
          _resolvedPlatform == TargetPlatform.iOS) {
        final handoff = await systemOAuthClient.login(
          returnTo: request.returnTo,
        );
        return NativeSocialLoginResult(
          provider: 'kakao',
          browserSessionHandoff: handoff,
        );
      }

      final accessToken = await _login(request.loginMode);
      return NativeSocialLoginResult(
        provider: 'kakao',
        accessToken: accessToken,
      );
    } on NativeSocialLoginCanceledException {
      rethrow;
    } on NativeSocialLoginException {
      rethrow;
    } on kakao.KakaoClientException catch (error) {
      if (error.reason == kakao.ClientErrorCause.cancelled) {
        throw const NativeSocialLoginCanceledException();
      }

      throw NativeSocialLoginException(
        'Kakao native login failed.',
        diagnosticCode: 'kakao-${error.reason.name}',
      );
    } on PlatformException catch (error) {
      if (error.code.toUpperCase() == 'CANCELED') {
        throw const NativeSocialLoginCanceledException();
      }

      throw NativeSocialLoginException(
        'Kakao native login failed.',
        diagnosticCode: 'kakao-platform-${error.code.toLowerCase()}',
      );
    } catch (_) {
      throw const NativeSocialLoginException('Kakao native login failed.');
    }
  }

  TargetPlatform get _resolvedPlatform => platform ?? defaultTargetPlatform;

  Future<String> _login(NativeSocialLoginMode mode) async {
    if (mode == NativeSocialLoginMode.account) {
      return client.loginWithKakaoAccount(forceLogin: true);
    }

    if (!await client.isKakaoTalkInstalled()) {
      return client.loginWithKakaoAccount();
    }

    try {
      return await client.loginWithKakaoTalk();
    } catch (_) {
      return client.loginWithKakaoAccount();
    }
  }
}

class SdkKakaoLoginClient implements KakaoLoginClient {
  const SdkKakaoLoginClient();

  @override
  Future<bool> isKakaoTalkInstalled() {
    return kakao.isKakaoTalkInstalled();
  }

  @override
  Future<String> loginWithKakaoTalk() async {
    final token = await kakao.UserApi.instance.loginWithKakaoTalk();
    return token.accessToken;
  }

  @override
  Future<String> loginWithKakaoAccount({bool forceLogin = false}) async {
    final token = await kakao.UserApi.instance.loginWithKakaoAccount(
      prompts: forceLogin ? <kakao.Prompt>[kakao.Prompt.login] : null,
    );
    return token.accessToken;
  }
}
