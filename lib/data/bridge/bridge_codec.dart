import 'dart:convert';

import 'bridge_message.dart';

enum BridgeCodecErrorCode {
  invalidJson,
  invalidEnvelope,
}

class BridgeCodecException implements Exception {
  const BridgeCodecException(this.code, this.message);

  final BridgeCodecErrorCode code;
  final String message;

  @override
  String toString() {
    return 'BridgeCodecException($code): $message';
  }
}

class BridgeCodec {
  const BridgeCodec._();

  static BridgeMessage decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw BridgeCodecException(
        BridgeCodecErrorCode.invalidJson,
        error.message,
      );
    }

    if (decoded is! Map<String, Object?>) {
      throw const BridgeCodecException(
        BridgeCodecErrorCode.invalidEnvelope,
        'Bridge message must be a JSON object.',
      );
    }

    return _decodeEnvelope(decoded);
  }

  static String encode(BridgeMessage message) {
    return jsonEncode(message.toJson());
  }

  static BridgeMessage _decodeEnvelope(Map<String, Object?> envelope) {
    final version = envelope['version'];
    final id = envelope['id'];
    final type = envelope['type'];
    final directionValue = envelope['direction'];
    final payload = envelope['payload'];
    final timestamp = envelope['timestamp'];

    if (version != 1 ||
        (id != null && (id is! String || id.isEmpty)) ||
        type is! String ||
        type.isEmpty ||
        directionValue is! String ||
        payload is! Map ||
        (timestamp != null && (timestamp is! int || timestamp < 0))) {
      throw const BridgeCodecException(
        BridgeCodecErrorCode.invalidEnvelope,
        'Bridge message envelope is invalid.',
      );
    }

    final direction = BridgeDirection.tryParse(directionValue);
    if (direction == null) {
      throw const BridgeCodecException(
        BridgeCodecErrorCode.invalidEnvelope,
        'Bridge message direction is invalid.',
      );
    }

    return BridgeMessage(
      version: version as int,
      id: id as String?,
      type: type,
      direction: direction,
      payload: _copyPayload(payload),
      timestamp: timestamp as int?,
    );
  }

  static Map<String, Object?> _copyPayload(Map<dynamic, dynamic> payload) {
    final copied = <String, Object?>{};
    for (final entry in payload.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const BridgeCodecException(
          BridgeCodecErrorCode.invalidEnvelope,
          'Bridge message payload keys must be strings.',
        );
      }

      copied[key] = entry.value;
    }

    return copied;
  }
}
