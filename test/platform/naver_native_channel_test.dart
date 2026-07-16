import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the Naver Flutter SDK instead of a Granite-owned native channel',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final sceneDelegate =
        File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/granite/climbing/MainActivity.kt',
    ).readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final nativeChannel = File(
      'lib/features/auth/native_social_login_channel.dart',
    );

    expect(pubspec, contains('naver_login_sdk:'));
    expect(main, contains('NaverLoginSdkClient().initialize'));
    expect(appDelegate, isNot(contains('NidThirdPartyLogin')));
    expect(appDelegate, isNot(contains('native_social_login')));
    expect(sceneDelegate,
        contains('super.scene(scene, openURLContexts: URLContexts)'));
    expect(sceneDelegate, contains('appDelegate.application?('));
    expect(podfile, isNot(contains("pod 'NidThirdPartyLogin'")));
    expect(gradle, isNot(contains('com.navercorp.nid:oauth')));
    expect(gradle, isNot(contains('NAVER_CLIENT_SECRET')));
    expect(nativeChannel.existsSync(), isFalse);
    expect(mainActivity, contains('class MainActivity : FlutterActivity()'));
    expect(mainActivity, isNot(contains('NidOAuth')));
    expect(mainActivity, isNot(contains('MethodChannel')));
    expect(plist, contains('graniteclimbingnaverlogin'));
    expect(plist, contains('naversearchapp'));
    expect(plist, contains('naversearchthirdlogin'));
  });
}
