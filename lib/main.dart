import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/kakao_sdk_initializer.dart';
import 'features/auth/naver_native_login_client.dart';
import 'features/auth/naver_sdk_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeKakaoSdk();
  await initializeNaverSdk(
    initializeNativeSdk: () => const NaverLoginSdkClient().initialize(),
  );

  runApp(
    GraniteApp(
      initialUrl: Uri.parse(AppConstants.defaultWebUrl),
    ),
  );
}
