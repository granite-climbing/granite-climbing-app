import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android registers the Naver native social login channel stub', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/granite/climbing/MainActivity.kt',
    ).readAsStringSync();

    expect(mainActivity, contains('com.granite.climbing/native_social_login'));
    expect(mainActivity, contains('loginWithNaver'));
    expect(mainActivity, contains('not_configured'));
  });

  test('iOS registers the Naver native social login channel stub', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(appDelegate, contains('com.granite.climbing/native_social_login'));
    expect(appDelegate, contains('loginWithNaver'));
    expect(appDelegate, contains('not_configured'));
  });
}
