import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/app_auth_repository.dart';
import 'package:granite_climbing_app/features/auth/app_auth_session.dart';
import 'package:granite_climbing_app/features/auth/auth_gate.dart';
import 'package:granite_climbing_app/features/auth/native_auth_service.dart';

void main() {
  testWidgets(
      'shows native login before the webview when no app session exists',
      (tester) async {
    final repository = MemoryAppAuthRepository();
    final authService = RecordingNativeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          initialUrl: Uri.parse('https://granite.kr/me'),
          authRepository: repository,
          nativeAuthService: authService,
          webViewBuilder: (context, url) => Text('webview: $url'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Granite 시작하기'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.textContaining('webview:'), findsNothing);
  });

  testWidgets('stores an app session and opens the webview after native login',
      (tester) async {
    final repository = MemoryAppAuthRepository();
    final authService = RecordingNativeAuthService(provider: 'kakao');

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          initialUrl: Uri.parse('https://granite.kr/me'),
          authRepository: repository,
          nativeAuthService: authService,
          webViewBuilder: (context, url) => Text('webview: $url'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump();
    await tester.pump();

    expect(authService.requests.single.providerHint, 'kakao');
    expect((await repository.readSession())?.provider, 'kakao');
    expect(find.text('webview: https://granite.kr/me'), findsOneWidget);
  });

  testWidgets('opens the webview immediately when an app session exists',
      (tester) async {
    final repository = MemoryAppAuthRepository(
      initialSession: const AppAuthSession(provider: 'apple'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          initialUrl: Uri.parse('https://granite.kr/'),
          authRepository: repository,
          nativeAuthService: RecordingNativeAuthService(),
          webViewBuilder: (context, url) => Text('webview: $url'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Granite 시작하기'), findsNothing);
    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
  });
}

class RecordingNativeAuthService implements NativeAuthService {
  RecordingNativeAuthService({this.provider = 'native'});

  final String provider;
  final List<NativeLoginRequest> requests = [];

  @override
  Future<NativeLoginStart> startLogin(NativeLoginRequest request) async {
    requests.add(request);
    return NativeLoginStart(provider: request.providerHint ?? provider);
  }

  @override
  Future<void> logout() async {}
}
