import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/native_auth_session_request.dart';
import '../../../features/auth/native_social_login_service.dart';
import '../bridge_handler.dart';
import '../bridge_message.dart';

typedef NativeAuthUrlLoader = Future<void> Function(Uri url);
typedef NativeAuthSessionRequestLoader = Future<void> Function(
  NativeAuthSessionLoadRequest request,
);

class NativeAuthBridgeHandler implements BridgeHandler {
  const NativeAuthBridgeHandler({
    this.loginService = const DevNativeSocialLoginService(),
    this.loadUrl,
    this.loadSessionRequest,
    this.webBaseUrl,
  });

  final NativeSocialLoginService loginService;
  final NativeAuthUrlLoader? loadUrl;
  final NativeAuthSessionRequestLoader? loadSessionRequest;
  final Uri? webBaseUrl;

  @override
  bool canHandle(BridgeMessage message) {
    return message.type == 'auth.native.login.requested' &&
        message.direction == BridgeDirection.webToNative;
  }

  @override
  FutureOr<void> handle(BridgeMessage message, BridgeSender sender) async {
    final provider = _readNativeProvider(message.payload['provider']);
    if (provider == null) return;

    final returnTo = _readReturnTo(message.payload['returnTo']);
    final NativeSocialLoginResult loginResult;

    try {
      loginResult = await loginService.login(
        NativeSocialLoginRequest(
          provider: provider,
          returnTo: returnTo,
        ),
      );
    } on NativeSocialLoginCanceledException {
      return;
    } catch (error) {
      debugPrint(
        '[granite native auth] login failed for provider $provider: $error',
      );
      await _loadLoginError('native_login_failed');
      return;
    }

    try {
      final request = _sessionRequestBuilder.build(
        NativeAuthSessionRequest(
          provider: loginResult.provider,
          accessToken: loginResult.accessToken,
          idToken: loginResult.idToken,
          returnTo: returnTo,
        ),
      );

      await loadSessionRequest?.call(request);
    } catch (error) {
      debugPrint(
        '[granite native auth] session handoff failed for provider $provider: $error',
      );
      await _loadLoginError('native_exchange_failed');
    }
  }

  NativeAuthSessionRequestBuilder get _sessionRequestBuilder {
    return NativeAuthSessionRequestBuilder(
      webBaseUrl: _resolvedWebBaseUrl,
    );
  }

  Future<void> _loadLoginError(String error) async {
    await loadUrl?.call(
      _webUrl('/login').replace(
        queryParameters: <String, String>{
          'error': error,
        },
      ),
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

  String? _readNativeProvider(Object? value) {
    if (value == 'kakao' ||
        value == 'naver' ||
        value == 'google' ||
        value == 'apple') {
      return value as String;
    }

    return null;
  }

  String? _readReturnTo(Object? value) {
    if (value is! String) return null;
    if (!value.startsWith('/') || value.startsWith('//')) return null;

    return value;
  }
}
