import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/connectivity/network_status_service.dart';
import 'core/constants/app_constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    GraniteApp(
      initialUrl: Uri.parse(AppConstants.defaultWebUrl),
      networkStatusService: AppConstants.forceOffline
          ? const ForcedOfflineNetworkStatusService()
          : ConnectivityNetworkStatusService(
              checkUri: Uri.parse(AppConstants.networkCheckUrl),
              timeout: const Duration(
                milliseconds: AppConstants.networkCheckTimeoutMs,
              ),
              slowThreshold: const Duration(
                milliseconds: AppConstants.slowNetworkThresholdMs,
              ),
            ),
      startupDelay: Duration(milliseconds: AppConstants.startDelayMs),
      webViewFirstLoadWarningDelay: const Duration(
        milliseconds: AppConstants.webViewFirstLoadWarningMs,
      ),
    ),
  );
}
