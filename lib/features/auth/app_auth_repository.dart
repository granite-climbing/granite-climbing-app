import 'app_auth_session.dart';

abstract interface class AppAuthRepository {
  Future<AppAuthSession?> readSession();

  Future<void> saveSession(AppAuthSession session);

  Future<void> clearSession();
}

class MemoryAppAuthRepository implements AppAuthRepository {
  MemoryAppAuthRepository({
    AppAuthSession? initialSession,
  }) : _session = initialSession;

  AppAuthSession? _session;

  @override
  Future<AppAuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AppAuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }
}
