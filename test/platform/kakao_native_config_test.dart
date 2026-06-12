import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest registers Kakao login redirect scheme', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(buildGradle, contains('KAKAO_NATIVE_APP_KEY'));
    expect(buildGradle, contains('kakaoNativeAppKey'));
    expect(
      manifest,
      contains('com.kakao.sdk.flutter.auth.AuthCodeHandlerActivity'),
    );
    expect(manifest, contains('android:scheme="kakao\${kakaoNativeAppKey}"'));
    expect(manifest, contains('android:host="oauth"'));
  });

  test('iOS Info.plist registers Kakao allowlist and URL scheme placeholder',
      () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();

    expect(plist, contains('kakaokompassauth'));
    expect(plist, contains('kakao\$(KAKAO_NATIVE_APP_KEY)'));
    expect(podfile, contains("platform :ios, '13.0'"));
  });
}
