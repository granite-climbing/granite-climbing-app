import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/native_auth_diagnostics.dart';
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
    this.diagnostics = const NativeAuthDiagnostics(),
  });

  final NativeSocialLoginService loginService;
  final NativeAuthUrlLoader? loadUrl;
  final NativeAuthSessionRequestLoader? loadSessionRequest;
  final Uri? webBaseUrl;
  final NativeAuthDiagnostics diagnostics;

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
    final loginMode = _readLoginMode(
      provider,
      message.payload['loginMode'],
    );
    if (provider == 'naver') {
      debugPrint(
          '[granite naver] route=native-sdk bridge_received provider=naver');
    }
    final NativeSocialLoginResult loginResult;

    try {
      diagnostics.event(
        provider: provider,
        stage: 'provider_login',
        status: 'started',
      );
      loginResult = await loginService.login(
        NativeSocialLoginRequest(
          provider: provider,
          returnTo: returnTo,
          loginMode: loginMode,
        ),
      );
    } on NativeSocialLoginCanceledException {
      diagnostics.event(
        provider: provider,
        stage: 'provider_login',
        status: 'failed',
        errorCode: 'cancelled',
      );
      await _sendLoginFailed(sender, message.id, 'cancelled');
      return;
    } on NativeSocialLoginException catch (error) {
      diagnostics.event(
        provider: provider,
        stage: 'provider_login',
        status: 'failed',
        errorCode: error.diagnosticCode,
        providerStatus: error.providerStatus,
      );
      await _sendLoginFailed(sender, message.id, 'failed');
      return;
    } catch (_) {
      diagnostics.event(
        provider: provider,
        stage: 'provider_login',
        status: 'failed',
        errorCode: 'native-login-failed',
      );
      await _sendLoginFailed(sender, message.id, 'failed');
      return;
    }

    diagnostics.event(
      provider: provider,
      stage: 'provider_login',
      status: 'completed',
    );

    try {
      diagnostics.event(
        provider: provider,
        stage: 'session_sync',
        status: 'started',
      );
      final browserHandoff = loginResult.browserSessionHandoff;
      final request = browserHandoff == null
          ? _sessionRequestBuilder.build(
              NativeAuthSessionRequest(
                provider: loginResult.provider,
                accessToken: loginResult.accessToken,
                idToken: loginResult.idToken,
                returnTo: returnTo,
              ),
            )
          : _browserSessionRequestBuilder.build(
              NativeBrowserSessionRequest(
                handoff: browserHandoff.token,
                verifier: browserHandoff.verifier,
              ),
            );

      await loadSessionRequest?.call(request);
      diagnostics.event(
        provider: provider,
        stage: 'session_sync',
        status: 'completed',
      );
    } catch (_) {
      diagnostics.event(
        provider: provider,
        stage: 'session_sync',
        status: 'failed',
        errorCode: 'session-sync-failed',
      );
      await _sendLoginFailed(sender, message.id, 'failed');
    }
  }

  NativeAuthSessionRequestBuilder get _sessionRequestBuilder {
    return NativeAuthSessionRequestBuilder(
      webBaseUrl: _resolvedWebBaseUrl,
    );
  }

  NativeBrowserSessionRequestBuilder get _browserSessionRequestBuilder {
    return NativeBrowserSessionRequestBuilder(
      webBaseUrl: _resolvedWebBaseUrl,
    );
  }

  Uri get _resolvedWebBaseUrl {
    return webBaseUrl ?? Uri.parse(AppConstants.defaultWebUrl);
  }

  Future<void> _sendLoginFailed(
    BridgeSender sender,
    String? id,
    String reason,
  ) {
    return sender.send(
      BridgeMessage(
        version: 1,
        id: id,
        type: 'auth.native.login.failed',
        direction: BridgeDirection.nativeToWeb,
        payload: <String, Object?>{'reason': reason},
      ),
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

  NativeSocialLoginMode _readLoginMode(String provider, Object? value) {
    if (provider != 'kakao') {
      return NativeSocialLoginMode.talkPreferred;
    }

    if (value == 'account') {
      return NativeSocialLoginMode.account;
    }

    return NativeSocialLoginMode.talkPreferred;
  }

  String? _readReturnTo(Object? value) {
    if (value is! String) return null;
    if (!value.startsWith('/') || value.startsWith('//')) return null;

    return value;
  }
}
