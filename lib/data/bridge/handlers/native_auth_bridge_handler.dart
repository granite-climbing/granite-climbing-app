import 'dart:async';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/native_auth_exchange_service.dart';
import '../../../features/auth/native_social_login_service.dart';
import '../bridge_handler.dart';
import '../bridge_message.dart';

typedef NativeAuthUrlLoader = Future<void> Function(Uri url);

class NativeAuthBridgeHandler implements BridgeHandler {
  const NativeAuthBridgeHandler({
    this.loginService = const DevNativeSocialLoginService(),
    this.exchangeService,
    this.loadUrl,
    this.webBaseUrl,
  });

  final NativeSocialLoginService loginService;
  final NativeAuthExchangeGateway? exchangeService;
  final NativeAuthUrlLoader? loadUrl;
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
    } catch (_) {
      await _loadLoginError('native_login_failed');
      return;
    }

    try {
      final result = await _exchangeService.exchange(
        NativeAuthExchangeRequest(
          provider: loginResult.provider,
          accessToken: loginResult.accessToken,
          returnTo: returnTo,
        ),
      );

      await loadUrl?.call(result.consumeUrl);
    } catch (_) {
      await _loadLoginError('native_exchange_failed');
    }
  }

  NativeAuthExchangeGateway get _exchangeService {
    return exchangeService ??
        NativeAuthExchangeService(
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
    if (value == 'kakao' || value == 'naver') {
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
