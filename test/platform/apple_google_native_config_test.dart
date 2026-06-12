import 'dart:io';

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
}
