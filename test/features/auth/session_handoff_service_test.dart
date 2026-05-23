import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/session_handoff_service.dart';

void main() {
  test('dev session handoff creates a web sync handoff code', () async {
    const service = DevSessionHandoffService();

    final handoff = await service.createHandoff(
      const SessionHandoffRequest(
        returnTo: '/me',
        reason: 'native_login',
      ),
    );

    expect(handoff.handoffCode, isNotEmpty);
    expect(handoff.returnTo, '/me');
    expect(handoff.reason, 'native_login');
  });
}
