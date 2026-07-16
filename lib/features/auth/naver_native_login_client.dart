import 'dart:async';
import 'dart:io';

import 'package:naver_login_sdk/naver_login_sdk.dart';

import '../../core/constants/app_constants.dart';

abstract interface class NaverNativeLoginClient {
  Future<bool> initialize();

  Future<bool> login();

  Future<String> getAccessToken();
}

class NaverLoginSdkClient implements NaverNativeLoginClient {
  const NaverLoginSdkClient();

  @override
  Future<bool> initialize() async {
    await NaverLoginSDK.initialize(
      urlScheme: Platform.isIOS ? AppConstants.naverUrlScheme : null,
      clientId: AppConstants.naverClientId,
      clientSecret: AppConstants.naverClientSecret,
      clientName: AppConstants.naverClientName,
    );
    return true;
  }

  @override
  Future<bool> login() {
    final completer = Completer<bool>();

    void complete(bool value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    NaverLoginSDK.login(
      callback: OAuthLoginCallback(
        onSuccess: () => complete(true),
        onFailure: (_, __) => complete(false),
        onError: (_, __) => complete(false),
      ),
    ).then((didLogin) {
      if (didLogin) {
        complete(true);
      }
    }).catchError((Object _) {
      complete(false);
    });

    return completer.future;
  }

  @override
  Future<String> getAccessToken() => NaverLoginSDK.getAccessToken();
}
