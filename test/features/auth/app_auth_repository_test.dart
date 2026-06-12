import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/app_auth_repository.dart';
import 'package:granite_climbing_app/features/auth/app_auth_session.dart';

void main() {
  test('secure repository persists the app auth session through storage',
      () async {
    final store = InMemoryAppAuthSessionStore();
    final firstRepository = SecureAppAuthRepository(store: store);
    final secondRepository = SecureAppAuthRepository(store: store);

    await firstRepository.saveSession(
      const AppAuthSession(provider: 'kakao'),
    );

    expect((await secondRepository.readSession())?.provider, 'kakao');
  });

  test('secure repository clears the stored app auth session', () async {
    final store = InMemoryAppAuthSessionStore();
    final repository = SecureAppAuthRepository(store: store);

    await repository.saveSession(
      const AppAuthSession(provider: 'google'),
    );
    await repository.clearSession();

    expect(await repository.readSession(), isNull);
  });

  test('secure repository drops unreadable session payloads', () async {
    final store = InMemoryAppAuthSessionStore();
    final repository = SecureAppAuthRepository(store: store);

    await store.write(SecureAppAuthRepository.sessionStorageKey, 'not-json');

    expect(await repository.readSession(), isNull);
    expect(await store.read(SecureAppAuthRepository.sessionStorageKey), isNull);
  });
}

class InMemoryAppAuthSessionStore implements AppAuthSessionStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
