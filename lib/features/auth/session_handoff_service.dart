class SessionHandoffRequest {
  const SessionHandoffRequest({
    this.returnTo,
    this.reason = 'native_login',
  });

  final String? returnTo;
  final String reason;
}

class SessionHandoff {
  const SessionHandoff({
    required this.handoffCode,
    this.returnTo,
    this.reason = 'native_login',
  });

  final String handoffCode;
  final String? returnTo;
  final String reason;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'handoffCode': handoffCode,
      if (returnTo != null) 'returnTo': returnTo,
      'reason': reason,
    };
  }
}

abstract interface class SessionHandoffService {
  Future<SessionHandoff> createHandoff(SessionHandoffRequest request);
}

class DevSessionHandoffService implements SessionHandoffService {
  const DevSessionHandoffService();

  static const handoffCode = 'dev-native-session-handoff';

  @override
  Future<SessionHandoff> createHandoff(SessionHandoffRequest request) async {
    return SessionHandoff(
      handoffCode: handoffCode,
      returnTo: request.returnTo,
      reason: request.reason,
    );
  }
}
