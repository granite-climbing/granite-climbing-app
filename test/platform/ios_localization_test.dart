import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Runner project defaults to Korean localization', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(project, contains('developmentRegion = ko;'));
    expect(project, contains('knownRegions = ('));
    expect(project, contains('ko,'));
  });
}
