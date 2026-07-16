import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/naver_sdk_initializer.dart';

void main() {
  test('initializes the native Naver SDK during app startup', () async {
    var calls = 0;
    final logs = <String>[];

    final initialized = await initializeNaverSdk(
      initializeNativeSdk: () async {
        calls += 1;
        return true;
      },
      log: logs.add,
    );

    expect(initialized, isTrue);
    expect(calls, 1);
    expect(logs, ['[granite naver] startup native_sdk_initialized=true']);
  });
}
