import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/app/app.dart';
import 'package:granite_climbing_app/features/auth/app_auth_repository.dart';

void main() {
  testWidgets('starts with native login before showing the Granite webview',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        authRepository: MemoryAppAuthRepository(),
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Granite 시작하기'), findsOneWidget);
    expect(find.text('webview: https://granite.kr/'), findsNothing);
  });

  testWidgets('uses the uppercase app name', (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        authRepository: MemoryAppAuthRepository(),
        webViewBuilder: (context, url) => const SizedBox.shrink(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'GRANITE');
  });
}
