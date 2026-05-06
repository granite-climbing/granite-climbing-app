import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'network_status.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();
typedef ConnectivityWatch = Stream<List<ConnectivityResult>> Function();
typedef NetworkProbe = Future<NetworkProbeResult> Function(
  Uri uri,
  Duration timeout,
);

abstract class NetworkStatusService {
  Future<NetworkStatus> currentStatus();

  Stream<NetworkStatus> watchStatus();
}

class NetworkProbeResult {
  const NetworkProbeResult({
    required this.statusCode,
    required this.elapsed,
  });

  final int statusCode;
  final Duration elapsed;
}

class ForcedOfflineNetworkStatusService implements NetworkStatusService {
  const ForcedOfflineNetworkStatusService();

  @override
  Future<NetworkStatus> currentStatus() async {
    return NetworkStatus.offline;
  }

  @override
  Stream<NetworkStatus> watchStatus() {
    return Stream<NetworkStatus>.value(NetworkStatus.offline);
  }
}

class ConnectivityNetworkStatusService implements NetworkStatusService {
  ConnectivityNetworkStatusService({
    Connectivity? connectivity,
    Uri? checkUri,
    Duration timeout = const Duration(milliseconds: 3500),
    Duration slowThreshold = const Duration(milliseconds: 2500),
    ConnectivityCheck? checkConnectivity,
    ConnectivityWatch? watchConnectivity,
    NetworkProbe? probe,
  })  : _connectivity = connectivity ?? Connectivity(),
        _checkUri = checkUri ?? Uri.parse('https://granite.kr/'),
        _timeout = timeout,
        _slowThreshold = slowThreshold,
        _checkConnectivity = checkConnectivity,
        _watchConnectivity = watchConnectivity,
        _probe = probe ?? _defaultProbe;

  final Connectivity _connectivity;
  final Uri _checkUri;
  final Duration _timeout;
  final Duration _slowThreshold;
  final ConnectivityCheck? _checkConnectivity;
  final ConnectivityWatch? _watchConnectivity;
  final NetworkProbe _probe;

  @override
  Future<NetworkStatus> currentStatus() async {
    final results = await (_checkConnectivity?.call() ??
        _connectivity.checkConnectivity());
    return _qualityForResults(results);
  }

  @override
  Stream<NetworkStatus> watchStatus() {
    return (_watchConnectivity?.call() ?? _connectivity.onConnectivityChanged)
        .asyncMap(_qualityForResults)
        .distinct();
  }

  Future<NetworkStatus> _qualityForResults(
    List<ConnectivityResult> results,
  ) async {
    if (results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }

    try {
      final result = await _probe(_checkUri, _timeout).timeout(_timeout);
      if (result.statusCode < 200 || result.statusCode >= 400) {
        return NetworkStatus.blocked;
      }

      if (result.elapsed >= _slowThreshold) {
        return NetworkStatus.slow;
      }

      return NetworkStatus.online;
    } catch (_) {
      return NetworkStatus.blocked;
    }
  }

  static Future<NetworkProbeResult> _defaultProbe(
    Uri uri,
    Duration timeout,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final stopwatch = Stopwatch()..start();

    try {
      final request = await client.openUrl('HEAD', uri).timeout(timeout);
      request.followRedirects = true;
      final response = await request.close().timeout(timeout);
      stopwatch.stop();
      unawaited(response.drain<void>().catchError((_) {}));

      return NetworkProbeResult(
        statusCode: response.statusCode,
        elapsed: stopwatch.elapsed,
      );
    } finally {
      client.close(force: true);
    }
  }
}
