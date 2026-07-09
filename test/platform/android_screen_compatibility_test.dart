import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest supports large and xlarge tester devices', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:largeScreens="true"'));
    expect(manifest, contains('android:xlargeScreens="true"'));
  });
}
