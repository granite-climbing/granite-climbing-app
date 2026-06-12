import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/kakao_sdk_initializer.dart';

void main() {
  test('skips Kakao SDK initialization when native app key is empty', () async {
    final calls = <KakaoSdkInitCall>[];

    await initializeKakaoSdk(
      nativeAppKey: '',
      init: ({
        required nativeAppKey,
        required customScheme,
      }) async {
        calls.add(
          KakaoSdkInitCall(
            nativeAppKey: nativeAppKey,
            customScheme: customScheme,
          ),
        );
      },
    );

    expect(calls, isEmpty);
  });

  test('initializes Kakao SDK with native app key and custom scheme', () async {
    final calls = <KakaoSdkInitCall>[];

    await initializeKakaoSdk(
      nativeAppKey: 'native-key-1',
      init: ({
        required nativeAppKey,
        required customScheme,
      }) async {
        calls.add(
          KakaoSdkInitCall(
            nativeAppKey: nativeAppKey,
            customScheme: customScheme,
          ),
        );
      },
    );

    expect(calls.single.nativeAppKey, 'native-key-1');
    expect(calls.single.customScheme, 'kakaonative-key-1');
  });
}

class KakaoSdkInitCall {
  const KakaoSdkInitCall({
    required this.nativeAppKey,
    required this.customScheme,
  });

  final String nativeAppKey;
  final String customScheme;
}
