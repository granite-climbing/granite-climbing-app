import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

abstract interface class AppAuthSessionStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureAppAuthSessionStore implements AppAuthSessionStore {
  const FlutterSecureAppAuthSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}

class SecureAppAuthRepository implements AppAuthRepository {
  SecureAppAuthRepository({
    AppAuthSessionStore store = const FlutterSecureAppAuthSessionStore(),
  }) : _store = store;

  static const sessionStorageKey = 'granite.app_auth_session.v1';

  final AppAuthSessionStore _store;

  @override
  Future<AppAuthSession?> readSession() async {
    final payload = await _store.read(sessionStorageKey);
    if (payload == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        throw const FormatException('Invalid app auth session payload');
      }

      return AppAuthSession.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> saveSession(AppAuthSession session) {
    return _store.write(sessionStorageKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearSession() {
    return _store.delete(sessionStorageKey);
  }
}
