// ignore_for_file: avoid_print

typedef NativeAuthDiagnosticWriter = void Function(String entry);

class NativeAuthDiagnostics {
  const NativeAuthDiagnostics({
    this.write = _writeToSystemLog,
  });

  final NativeAuthDiagnosticWriter write;

  void event({
    required String provider,
    required String stage,
    required String status,
    String? errorCode,
    int? providerStatus,
  }) {
    final fields = <String>[
      'granite-native-auth',
      'provider=$provider',
      'stage=$stage',
      'status=$status',
      if (errorCode != null) 'errorCode=$errorCode',
      if (providerStatus != null &&
          providerStatus >= 100 &&
          providerStatus <= 599)
        'providerStatus=$providerStatus',
    ];

    write(fields.join(' '));
  }

  static void _writeToSystemLog(String entry) {
    print(entry);
  }
}
