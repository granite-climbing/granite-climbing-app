import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TestFlight release uses version 1.1.2 build 25 and iOS 15', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(pubspec, contains('version: 1.1.2+25'));
    expect(podfile, contains("platform :ios, '15.0'"));
    expect(podfile, isNot(contains("platform :ios, '13.0'")));

    final deploymentTargets = RegExp(
      r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);',
    ).allMatches(project).map((match) => match.group(1)).toList();

    expect(deploymentTargets, isNotEmpty);
    expect(deploymentTargets, everyElement('15.0'));
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
  });
}
