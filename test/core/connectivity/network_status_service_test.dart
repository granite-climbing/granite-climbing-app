import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:granite_climbing_app/core/connectivity/network_status.dart';
import 'package:granite_climbing_app/core/connectivity/network_status_service.dart';

void main() {
  test('forced offline network status service always reports offline',
      () async {
    const service = ForcedOfflineNetworkStatusService();

    expect(await service.currentStatus(), NetworkStatus.offline);
    await expectLater(
      service.watchStatus(),
      emits(NetworkStatus.offline),
    );
  });

  test('reports offline without probing when there is no connection', () async {
    var probeCount = 0;
    final service = ConnectivityNetworkStatusService(
      checkConnectivity: () async => [ConnectivityResult.none],
      watchConnectivity: () => const Stream.empty(),
      probe: (_, __) async {
        probeCount += 1;
        return const NetworkProbeResult(
          statusCode: 204,
          elapsed: Duration(milliseconds: 10),
        );
      },
    );

    expect(await service.currentStatus(), NetworkStatus.offline);
    expect(probeCount, 0);
  });

  test('reports online when the configured endpoint responds quickly',
      () async {
    final service = ConnectivityNetworkStatusService(
      checkConnectivity: () async => [ConnectivityResult.wifi],
      watchConnectivity: () => const Stream.empty(),
      probe: (_, __) async {
        return const NetworkProbeResult(
          statusCode: 204,
          elapsed: Duration(milliseconds: 50),
        );
      },
    );

    expect(await service.currentStatus(), NetworkStatus.online);
  });

  test('reports slow when the endpoint responds after the slow threshold',
      () async {
    final service = ConnectivityNetworkStatusService(
      slowThreshold: const Duration(milliseconds: 500),
      checkConnectivity: () async => [ConnectivityResult.mobile],
      watchConnectivity: () => const Stream.empty(),
      probe: (_, __) async {
        return const NetworkProbeResult(
          statusCode: 200,
          elapsed: Duration(milliseconds: 900),
        );
      },
    );

    expect(await service.currentStatus(), NetworkStatus.slow);
  });

  test('reports blocked when the endpoint cannot be reached', () async {
    final service = ConnectivityNetworkStatusService(
      checkConnectivity: () async => [ConnectivityResult.wifi],
      watchConnectivity: () => const Stream.empty(),
      probe: (_, __) async => throw Exception('timeout'),
    );

    expect(await service.currentStatus(), NetworkStatus.blocked);
  });

  test('reports blocked when the endpoint returns an error status', () async {
    final service = ConnectivityNetworkStatusService(
      checkConnectivity: () async => [ConnectivityResult.wifi],
      watchConnectivity: () => const Stream.empty(),
      probe: (_, __) async {
        return const NetworkProbeResult(
          statusCode: 500,
          elapsed: Duration(milliseconds: 50),
        );
      },
    );

    expect(await service.currentStatus(), NetworkStatus.blocked);
  });
}
