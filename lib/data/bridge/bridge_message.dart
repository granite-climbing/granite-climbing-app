enum BridgeDirection {
  nativeToWeb('native-to-web'),
  webToNative('web-to-native');

  const BridgeDirection(this.value);

  final String value;

  static BridgeDirection? tryParse(String value) {
    for (final direction in BridgeDirection.values) {
      if (direction.value == value) {
        return direction;
      }
    }

    return null;
  }
}

class BridgeMessage {
  const BridgeMessage({
    required this.version,
    required this.type,
    required this.direction,
    this.id,
    this.payload = const <String, Object?>{},
    this.timestamp,
  });

  final int version;
  final String? id;
  final String type;
  final BridgeDirection direction;
  final Map<String, Object?> payload;
  final int? timestamp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      if (id != null) 'id': id,
      'type': type,
      'direction': direction.value,
      'payload': payload,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }
}
