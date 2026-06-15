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

  test('iOS Info.plist registers Google Sign-In URL scheme', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      plist,
      contains(
        'com.googleusercontent.apps.679610827471-tdn6o2fqja8l5e9r8gu5rgvkbkiutcpd',
      ),
    );
  });

  test('production config passes Google OAuth client IDs to Flutter', () {
    final config = File('config/prod.json').readAsStringSync();

    expect(
      config,
      contains(
        '"GOOGLE_CLIENT_ID": "679610827471-tdn6o2fqja8l5e9r8gu5rgvkbkiutcpd.apps.googleusercontent.com"',
      ),
    );
    expect(
      config,
      contains(
        '"GOOGLE_SERVER_CLIENT_ID": "679610827471-3vv911t0f0h2gtkgokdb1drglcjlulch.apps.googleusercontent.com"',
      ),
    );
  });
}
