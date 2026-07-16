import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build ipa injects values from the selected environment file', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'flutter_granite_script_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));

    final fakeBin = Directory('${temporaryDirectory.path}/bin')..createSync();
    final capturedArguments =
        File('${temporaryDirectory.path}/flutter-arguments.txt');
    final fakeFlutter = File('${fakeBin.path}/flutter');
    await fakeFlutter.writeAsString('''#!/usr/bin/env bash
printf '%s\\n' "\$@" > "\$FLUTTER_ARGUMENTS_FILE"
''');
    await Process.run('chmod', ['+x', fakeFlutter.path]);

    final environmentFile = File('${temporaryDirectory.path}/prod.env');
    await environmentFile.writeAsString('''
GRANITE_WEB_URL=https://v2.granite.kr/
NAVER_CLIENT_SECRET=test-only-secret
NAVER_CLIENT_ID=test-client-id
NAVER_CLIENT_NAME=GRANITE
NAVER_URL_SCHEME=graniteclimbingnaverlogin
''');

    final result = await Process.run(
      'bash',
      ['tool/flutter_granite.sh', 'build', 'ipa'],
      workingDirectory: Directory.current.path,
      environment: {
        ...Platform.environment,
        'PATH': '${fakeBin.path}:${Platform.environment['PATH']}',
        'FLUTTER_ARGUMENTS_FILE': capturedArguments.path,
        'FLUTTER_GRANITE_ENV_FILE': environmentFile.path,
      },
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final arguments = await capturedArguments.readAsLines();
    expect(
        arguments,
        containsAll(<String>[
          'build',
          'ipa',
          '--release',
          '--export-options-plist=${Directory.current.path}/ios/ExportOptions.AppStoreConnect.plist',
          '--dart-define=GRANITE_WEB_URL=https://v2.granite.kr/',
          '--dart-define=NAVER_CLIENT_SECRET=test-only-secret',
          '--dart-define=NAVER_CLIENT_ID=test-client-id',
        ]));
  });
}
