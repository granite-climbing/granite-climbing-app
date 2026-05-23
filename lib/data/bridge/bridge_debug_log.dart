import 'package:flutter/foundation.dart';

import 'bridge_message.dart';

enum BridgeDebugDirection {
  inbound('inbound'),
  outbound('outbound');

  const BridgeDebugDirection(this.value);

  final String value;
}

class BridgeDebugEntry {
  const BridgeDebugEntry({
    required this.direction,
    required this.type,
    required this.timestamp,
    required this.payload,
    this.id,
  });

  final BridgeDebugDirection direction;
  final String type;
  final String? id;
  final int timestamp;
  final Map<String, Object?> payload;
}

class BridgeDebugLog {
  BridgeDebugLog({
    this.capacity = 50,
    this.enabled = kDebugMode,
    int Function()? now,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int capacity;
  final bool enabled;
  final int Function() _now;
  final List<BridgeDebugEntry> _entries = [];

  List<BridgeDebugEntry> get entries => List.unmodifiable(_entries);

  void recordInbound(BridgeMessage message) {
    _record(BridgeDebugDirection.inbound, message);
  }

  void recordOutbound(BridgeMessage message) {
    _record(BridgeDebugDirection.outbound, message);
  }

  void clear() {
    _entries.clear();
  }

  void _record(BridgeDebugDirection direction, BridgeMessage message) {
    if (!enabled || capacity <= 0) return;

    _entries.add(
      BridgeDebugEntry(
        direction: direction,
        type: message.type,
        id: message.id,
        timestamp: _now(),
        payload: _sanitizePayload(message.payload),
      ),
    );

    while (_entries.length > capacity) {
      _entries.removeAt(0);
    }
  }

  static Map<String, Object?> _sanitizePayload(Map<String, Object?> payload) {
    return payload.map(
      (key, value) => MapEntry(key, _sanitizeValue(key, value)),
    );
  }

  static Object? _sanitizeValue(String key, Object? value) {
    if (_isSensitiveKey(key)) {
      return '[redacted]';
    }

    if (value is Map) {
      return value.map(
        (nestedKey, nestedValue) => MapEntry(
          nestedKey.toString(),
          _sanitizeValue(nestedKey.toString(), nestedValue),
        ),
      );
    }

    if (value is List) {
      return value
          .map(
            (item) => item is Map
                ? item.map(
                    (nestedKey, nestedValue) => MapEntry(
                      nestedKey.toString(),
                      _sanitizeValue(nestedKey.toString(), nestedValue),
                    ),
                  )
                : item,
          )
          .toList();
    }

    return value;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('cookie') ||
        normalized.contains('secret') ||
        normalized.contains('handoff') ||
        normalized.contains('authorization') ||
        normalized == 'email';
  }
}
