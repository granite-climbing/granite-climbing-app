import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build ipa injects default Google client and server IDs', () async {
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
GOOGLE_CLIENT_ID=ios-client-id
GOOGLE_CLIENT_ID_APK=apk-client-id
GOOGLE_SERVER_CLIENT_ID=web-server-client-id
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
        '--dart-define=GOOGLE_CLIENT_ID=ios-client-id',
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=web-server-client-id',
      ]),
    );
  });

  test('build apk overrides only the Google client ID', () async {
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
GOOGLE_CLIENT_ID=ios-client-id
GOOGLE_CLIENT_ID_APK=apk-client-id
GOOGLE_SERVER_CLIENT_ID=web-server-client-id
''');

    final result = await Process.run(
      'bash',
      ['tool/flutter_granite.sh', 'build', 'apk'],
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
        'apk',
        '--release',
        '--dart-define=GRANITE_WEB_URL=https://v2.granite.kr/',
        '--dart-define=NAVER_CLIENT_SECRET=test-only-secret',
        '--dart-define=NAVER_CLIENT_ID=test-client-id',
        '--dart-define=GOOGLE_CLIENT_ID=apk-client-id',
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=web-server-client-id',
      ]),
    );
    expect(
      arguments.any((argument) => argument.startsWith('--export-options')),
      isFalse,
    );
  });

  test('build appbundle preserves the generic Google client ID', () async {
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
GOOGLE_CLIENT_ID=play-client-id
GOOGLE_CLIENT_ID_APK=apk-client-id
GOOGLE_SERVER_CLIENT_ID=web-server-client-id
''');

    final result = await Process.run(
      'bash',
      ['tool/flutter_granite.sh', 'build', 'appbundle'],
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
        'appbundle',
        '--release',
        '--dart-define=GOOGLE_CLIENT_ID=play-client-id',
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=web-server-client-id',
      ]),
    );
    expect(arguments,
        isNot(contains('--dart-define=GOOGLE_CLIENT_ID=apk-client-id')));
    expect(
      arguments.any((argument) => argument.startsWith('--export-options')),
      isFalse,
    );
  });
}
