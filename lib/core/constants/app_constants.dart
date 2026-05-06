class AppConstants {
  const AppConstants._();

  static const defaultWebUrl = String.fromEnvironment(
    'GRANITE_WEB_URL',
    defaultValue: 'https://granite.kr/',
  );

  static const offlineWebAssetPath = 'assets/offline_web/index.html';

  static const forceOffline = bool.fromEnvironment(
    'GRANITE_FORCE_OFFLINE',
  );

  static const startDelayMs = int.fromEnvironment(
    'GRANITE_START_DELAY_MS',
  );

  static const networkCheckUrl = String.fromEnvironment(
    'GRANITE_NETWORK_CHECK_URL',
    defaultValue: 'https://granite.kr/',
  );

  static const networkCheckTimeoutMs = int.fromEnvironment(
    'GRANITE_NETWORK_CHECK_TIMEOUT_MS',
    defaultValue: 3500,
  );

  static const slowNetworkThresholdMs = int.fromEnvironment(
    'GRANITE_SLOW_NETWORK_THRESHOLD_MS',
    defaultValue: 2500,
  );

  static const webViewFirstLoadWarningMs = int.fromEnvironment(
    'GRANITE_WEBVIEW_FIRST_LOAD_WARNING_MS',
    defaultValue: 8000,
  );
}
