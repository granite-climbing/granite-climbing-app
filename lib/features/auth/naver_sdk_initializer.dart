import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef NaverSdkInitializer = Future<bool> Function();
typedef NaverSdkLog = void Function(String message);

Future<bool> initializeNaverSdk({
  required NaverSdkInitializer initializeNativeSdk,
  NaverSdkLog log = _defaultLog,
}) async {
  try {
    final initialized = await initializeNativeSdk();
    log('[granite naver] startup native_sdk_initialized=$initialized');
    return initialized;
  } on PlatformException catch (error) {
    log('[granite naver] startup native_sdk_initialization_failed code=${error.code}');
    return false;
  }
}

void _defaultLog(String message) {
  debugPrint(message);
}
