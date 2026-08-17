import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../core/constants/app_constants.dart';
import 'native_social_login_service.dart';

typedef KakaoSystemAuthenticator = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});
typedef SecureRandomBytes = Uint8List Function(int length);

class KakaoSystemOAuthClient {
  const KakaoSystemOAuthClient({
    this.webBaseUrl,
    this.authenticate,
    this.secureRandomBytes,
  });

  static const callbackScheme = 'graniteclimbing';

  final Uri? webBaseUrl;
  final KakaoSystemAuthenticator? authenticate;
  final SecureRandomBytes? secureRandomBytes;

  Future<NativeBrowserSessionHandoff> login({String? returnTo}) async {
    final verifier = _base64UrlWithoutPadding(
      (secureRandomBytes ?? _generateSecureRandomBytes)(32),
    );
    final challenge = _base64UrlWithoutPadding(
      sha256.convert(utf8.encode(verifier)).bytes,
    );
    final authorizationUrl = _webUrl('/api/auth/start/kakao').replace(
      queryParameters: <String, String>{
        'returnTo': _sanitizeReturnTo(returnTo),
        'native_system_auth': 'ios',
        'handoff_challenge': challenge,
      },
    );

    final String callback;
    try {
      callback = await (authenticate ?? _authenticate)(
        url: authorizationUrl.toString(),
        callbackUrlScheme: callbackScheme,
      );
    } on PlatformException catch (error) {
      if (_isCancellationCode(error.code)) {
        throw const NativeSocialLoginCanceledException();
      }

      throw NativeSocialLoginException(
        'Kakao system login failed.',
        diagnosticCode: 'kakao-system-${_safeDiagnosticCode(error.code)}',
      );
    }

    final callbackUri = Uri.tryParse(callback);
    if (!_isExpectedCallback(callbackUri)) {
      throw const NativeSocialLoginException(
        'Kakao system login returned an invalid callback.',
        diagnosticCode: 'kakao-system-invalid-callback',
      );
    }

    final error = callbackUri!.queryParameters['error'];
    if (error != null) {
      if (_isProviderCancellation(error)) {
        throw const NativeSocialLoginCanceledException();
      }

      throw const NativeSocialLoginException(
        'Kakao authorization failed.',
        diagnosticCode: 'kakao-system-provider-error',
      );
    }

    final handoffValues = callbackUri.queryParametersAll['handoff'];
    if (handoffValues == null ||
        handoffValues.length != 1 ||
        handoffValues.single.isEmpty) {
      throw const NativeSocialLoginException(
        'Kakao system login did not return a handoff.',
        diagnosticCode: 'kakao-system-missing-handoff',
      );
    }

    return NativeBrowserSessionHandoff(
      token: handoffValues.single,
      verifier: verifier,
    );
  }

  Uri get _resolvedWebBaseUrl {
    return webBaseUrl ?? Uri.parse(AppConstants.defaultWebUrl);
  }

  Uri _webUrl(String path) {
    return _resolvedWebBaseUrl.replace(
      path: path,
      query: null,
      fragment: null,
    );
  }

  static Future<String> _authenticate({
    required String url,
    required String callbackUrlScheme,
  }) {
    return FlutterWebAuth2.authenticate(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
    );
  }

  static Uint8List _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static String _base64UrlWithoutPadding(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _sanitizeReturnTo(String? value) {
    if (value == null || !value.startsWith('/') || value.startsWith('//')) {
      return '/me';
    }

    return value;
  }

  static bool _isExpectedCallback(Uri? uri) {
    return uri != null &&
        uri.scheme == callbackScheme &&
        uri.host == 'oauth' &&
        uri.path == '/kakao';
  }

  static bool _isCancellationCode(String code) {
    final normalized = code.toUpperCase();
    return normalized.contains('CANCEL');
  }

  static bool _isProviderCancellation(String error) {
    return error == 'access_denied' ||
        error == 'cancelled' ||
        error == 'user_cancelled';
  }

  static String _safeDiagnosticCode(String value) {
    final normalized = value.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9-]'),
          '-',
        );
    return normalized.isEmpty ? 'platform-error' : normalized;
  }
}
