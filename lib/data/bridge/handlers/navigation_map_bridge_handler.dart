import 'dart:async';

import '../../../features/navigation/native_map_service.dart';
import '../bridge_handler.dart';
import '../bridge_message.dart';

typedef NativeMapOpener = FutureOr<void> Function(NativeMapLocation location);

class NavigationMapBridgeHandler implements BridgeHandler {
  const NavigationMapBridgeHandler({
    required this.openMap,
  });

  final NativeMapOpener openMap;

  @override
  bool canHandle(BridgeMessage message) {
    return message.type == 'navigation.map.open.requested' &&
        message.direction == BridgeDirection.webToNative;
  }

  @override
  FutureOr<void> handle(BridgeMessage message, BridgeSender sender) async {
    final location = _readLocation(message.payload);
    if (location == null) return;

    await openMap(location);
  }

  NativeMapLocation? _readLocation(Map<String, Object?> payload) {
    final label = payload['label'];
    final latitude = _readCoordinate(payload['latitude']);
    final longitude = _readCoordinate(payload['longitude']);

    if (label is! String ||
        label.trim().isEmpty ||
        latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return NativeMapLocation(
      label: label.trim(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  double? _readCoordinate(Object? value) {
    if (value is! num) return null;

    final coordinate = value.toDouble();
    return coordinate.isFinite ? coordinate : null;
  }
}
