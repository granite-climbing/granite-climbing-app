import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_codec.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';

void main() {
  group('BridgeCodec', () {
    test('decodes a valid bridge envelope', () {
      final message = BridgeCodec.decode(
        '''
        {
          "version": 1,
          "id": "request-1",
          "type": "auth.session.sync.requested",
          "direction": "native-to-web",
          "payload": {
            "returnTo": "/me",
            "reason": "app_launch"
          },
          "timestamp": 1710000000000
        }
        ''',
      );

      expect(message.version, 1);
      expect(message.id, 'request-1');
      expect(message.type, 'auth.session.sync.requested');
      expect(message.direction, BridgeDirection.nativeToWeb);
      expect(message.payload, {
        'returnTo': '/me',
        'reason': 'app_launch',
      });
      expect(message.timestamp, 1710000000000);
    });

    test('encodes a bridge message with an empty payload', () {
      const message = BridgeMessage(
        version: 1,
        type: 'app.web.ready',
        direction: BridgeDirection.webToNative,
      );

      final encoded = BridgeCodec.encode(message);
      final decoded = BridgeCodec.decode(encoded);

      expect(decoded.version, 1);
      expect(decoded.type, 'app.web.ready');
      expect(decoded.direction, BridgeDirection.webToNative);
      expect(decoded.payload, isEmpty);
    });

    test('rejects malformed json as invalid_json', () {
      expect(
        () => BridgeCodec.decode('not-json'),
        throwsA(
          isA<BridgeCodecException>().having(
            (error) => error.code,
            'code',
            BridgeCodecErrorCode.invalidJson,
          ),
        ),
      );
    });

    test('rejects invalid envelopes as invalid_envelope', () {
      expect(
        () => BridgeCodec.decode(
          '''
          {
            "version": 1,
            "type": "app.web.ready",
            "direction": "sideways",
            "payload": {}
          }
          ''',
        ),
        throwsA(
          isA<BridgeCodecException>().having(
            (error) => error.code,
            'code',
            BridgeCodecErrorCode.invalidEnvelope,
          ),
        ),
      );
    });
  });
}
