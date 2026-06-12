import 'package:flutter/services.dart';

import 'native_social_login_service.dart';

class NativeSocialLoginChannel {
  const NativeSocialLoginChannel({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const channelName = 'com.granite.climbing/native_social_login';

  final MethodChannel _channel;

  Future<String> loginWithNaver() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'loginWithNaver',
      );
      final accessToken = result?['accessToken'];
      if (accessToken is String && accessToken.isNotEmpty) {
        return accessToken;
      }

      throw const NativeSocialLoginException(
        'Naver native login response is invalid.',
      );
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') {
        throw const NativeSocialLoginCanceledException();
      }

      throw NativeSocialLoginException(
        error.message ?? 'Naver native login failed.',
      );
    }
  }
}
