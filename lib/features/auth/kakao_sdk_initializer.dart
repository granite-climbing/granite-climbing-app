import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../core/constants/app_constants.dart';

typedef KakaoSdkInit = Future<void> Function({
  required String nativeAppKey,
  required String customScheme,
});

Future<void> initializeKakaoSdk({
  String nativeAppKey = AppConstants.kakaoNativeAppKey,
  KakaoSdkInit init = _initializeSdk,
}) async {
  if (nativeAppKey.isEmpty) {
    return;
  }

  await init(
    nativeAppKey: nativeAppKey,
    customScheme: 'kakao$nativeAppKey',
  );
}

Future<void> _initializeSdk({
  required String nativeAppKey,
  required String customScheme,
}) {
  return KakaoSdk.init(
    nativeAppKey: nativeAppKey,
    customScheme: customScheme,
  );
}
