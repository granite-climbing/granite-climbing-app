import 'dart:io';

import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

import '../../core/constants/app_constants.dart';
import 'native_social_login_service.dart';

class AppleLoginCredential {
  const AppleLoginCredential({
    this.identityToken,
    this.authorizationCode,
  });

  final String? identityToken;
  final String? authorizationCode;
}

abstract interface class AppleLoginClient {
  Future<AppleLoginCredential> login();
}

class AppleNativeLoginService implements NativeSocialLoginService {
  const AppleNativeLoginService({
    this.client = const SdkAppleLoginClient(),
  });

  final AppleLoginClient client;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    if (request.provider != 'apple') {
      throw NativeSocialLoginException(
        'Unsupported native login provider: ${request.provider}.',
      );
    }

    final AppleLoginCredential credential;
    try {
      credential = await client.login();
    } on apple.SignInWithAppleAuthorizationException catch (error) {
      if (error.code == apple.AuthorizationErrorCode.canceled) {
        throw const NativeSocialLoginCanceledException();
      }

      throw NativeSocialLoginException(
        'Apple native login failed: ${error.message}.',
      );
    } catch (_) {
      throw const NativeSocialLoginException('Apple native login failed.');
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const NativeSocialLoginException(
        'Apple native login returned no identity token.',
      );
    }

    return NativeSocialLoginResult(
      provider: 'apple',
      accessToken: '',
      idToken: idToken,
    );
  }
}

class SdkAppleLoginClient implements AppleLoginClient {
  const SdkAppleLoginClient();

  @override
  Future<AppleLoginCredential> login() async {
    final credential = await apple.SignInWithApple.getAppleIDCredential(
      scopes: const <apple.AppleIDAuthorizationScopes>[],
      webAuthenticationOptions: _webAuthenticationOptions(),
    );

    return AppleLoginCredential(
      identityToken: credential.identityToken,
      authorizationCode: credential.authorizationCode,
    );
  }

  apple.WebAuthenticationOptions? _webAuthenticationOptions() {
    if (!Platform.isAndroid) {
      return null;
    }

    final serviceId = AppConstants.appleServiceId;
    final redirectUri = Uri.tryParse(AppConstants.appleRedirectUri);
    if (serviceId.isEmpty || redirectUri == null) {
      throw StateError(
        'APPLE_SERVICE_ID and APPLE_REDIRECT_URI are required for Apple login on Android.',
      );
    }

    return apple.WebAuthenticationOptions(
      clientId: serviceId,
      redirectUri: redirectUri,
    );
  }
}
