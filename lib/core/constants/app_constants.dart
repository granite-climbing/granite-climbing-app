class AppConstants {
  const AppConstants._();

  static const defaultWebUrl = String.fromEnvironment(
    'GRANITE_WEB_URL',
    defaultValue: 'https://granite.kr/',
  );

  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );

  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static const appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
  );

  static const appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
  );
}
