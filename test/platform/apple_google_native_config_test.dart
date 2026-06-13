import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS project enables the Sign in with Apple entitlement', () {
    final entitlements = File('ios/Runner/Runner.entitlements');
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(entitlements.existsSync(), isTrue);
    expect(entitlements.readAsStringSync(),
        contains('com.apple.developer.applesignin'));
    expect(
        entitlements.readAsStringSync(), contains('<string>Default</string>'));
    expect(project,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'));
  });

  test('Android manifest registers the Sign in with Apple callback activity',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      contains(
          'com.aboutyou.dart_packages.sign_in_with_apple.SignInWithAppleCallback'),
    );
    expect(manifest, contains('android:scheme="signinwithapple"'));
    expect(manifest, contains('android:path="/callback"'));
  });

  test('production config includes Android Apple web authentication values',
      () {
    final config = jsonDecode(File('config/prod.json').readAsStringSync())
        as Map<String, Object?>;

    expect(config['APPLE_SERVICE_ID'], 'kr.granite.web');
    expect(config['APPLE_REDIRECT_URI'],
        'https://granite.kr/api/auth/native/apple/callback');
  });
}
