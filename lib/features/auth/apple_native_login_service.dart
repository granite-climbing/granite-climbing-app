import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

import '../../core/constants/app_constants.dart';
import 'native_social_login_service.dart';

int? appleProviderHttpStatus(String message) {
  final match = RegExp(r'\b([1-5]\d\d)\b').firstMatch(message);
  return match == null ? null : int.tryParse(match.group(1)!);
}

const nativeAppleWebCallbackStatePrefix = 'granite-native-apple-v1.';

String createNativeAppleWebCallbackState() {
  final random = Random.secure();
  final entropy = List<int>.generate(32, (_) => random.nextInt(256));
  return '$nativeAppleWebCallbackStatePrefix${base64UrlEncode(entropy).replaceAll('=', '')}';
}

bool isExpectedNativeAppleWebCallbackState({
  required String expected,
  required String? received,
}) {
  return expected.length > nativeAppleWebCallbackStatePrefix.length &&
      received != null &&
      received == expected;
}

Uri appleAndroidWebCallbackUri(Uri webBaseUri) {
  return webBaseUri.replace(
    path: '/api/auth/callback/apple',
    query: null,
    fragment: null,
  );
}

class AppleLoginCredential {
  const AppleLoginCredential({
    this.identityToken,
    this.authorizationCode,
    this.state,
  });

  final String? identityToken;
  final String? authorizationCode;
  final String? state;
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
        diagnosticCode: 'apple-native-login-failed',
        providerStatus: appleProviderHttpStatus(error.message),
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
    final callbackState =
        Platform.isAndroid ? createNativeAppleWebCallbackState() : null;
    final credential = await apple.SignInWithApple.getAppleIDCredential(
      scopes: const <apple.AppleIDAuthorizationScopes>[],
      webAuthenticationOptions: _webAuthenticationOptions(),
      state: callbackState,
    );

    if (callbackState != null &&
        !isExpectedNativeAppleWebCallbackState(
          expected: callbackState,
          received: credential.state,
        )) {
      throw StateError(
          'Apple callback state did not match the active login transaction.');
    }

    return AppleLoginCredential(
      identityToken: credential.identityToken,
      authorizationCode: credential.authorizationCode,
      state: credential.state,
    );
  }

  apple.WebAuthenticationOptions? _webAuthenticationOptions() {
    if (!Platform.isAndroid) {
      return null;
    }

    final serviceId = AppConstants.appleServiceId;
    final webBaseUri = Uri.tryParse(AppConstants.defaultWebUrl);
    if (serviceId.isEmpty || webBaseUri == null || !webBaseUri.hasScheme) {
      throw StateError(
        'APPLE_SERVICE_ID and GRANITE_WEB_URL are required for Apple login on Android.',
      );
    }

    return apple.WebAuthenticationOptions(
      clientId: serviceId,
      redirectUri: appleAndroidWebCallbackUri(webBaseUri),
    );
  }
}
