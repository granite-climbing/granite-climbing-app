class AppConstants {
  const AppConstants._();

  static const defaultWebUrl = String.fromEnvironment(
    'GRANITE_WEB_URL',
    defaultValue: 'https://granite.kr/app',
  );

  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );
}
