import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_debug_log.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';

void main() {
  test('stores recent bridge messages and masks sensitive payload values', () {
    final log = BridgeDebugLog(
      capacity: 2,
      now: () => 1710000000000,
    );

    log.recordInbound(
      const BridgeMessage(
        version: 1,
        id: 'message-1',
        type: 'auth.session.sync.requested',
        direction: BridgeDirection.nativeToWeb,
        payload: {
          'handoffCode': 'handoff-secret',
          'email': 'climber@example.com',
          'safe': 'visible',
          'nested': {
            'refreshToken': 'refresh-secret',
          },
        },
      ),
    );
    log.recordOutbound(
      const BridgeMessage(
        version: 1,
        id: 'message-2',
        type: 'auth.logout.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'cookie': 'granite_user=session',
        },
      ),
    );
    log.recordInbound(
      const BridgeMessage(
        version: 1,
        id: 'message-3',
        type: 'app.native.ready',
        direction: BridgeDirection.nativeToWeb,
        payload: {
          'platform': 'ios',
        },
      ),
    );

    expect(log.entries.map((entry) => entry.id), ['message-2', 'message-3']);
    expect(log.entries.first.payload, {
      'cookie': '[redacted]',
    });
  });

  test('can be disabled for non-debug logging paths', () {
    final log = BridgeDebugLog(enabled: false);

    log.recordInbound(
      const BridgeMessage(
        version: 1,
        type: 'app.native.ready',
        direction: BridgeDirection.nativeToWeb,
      ),
    );

    expect(log.entries, isEmpty);
  });
}
