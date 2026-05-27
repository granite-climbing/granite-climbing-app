import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/app/app.dart';
import 'package:granite_climbing_app/shared/widgets/app_start_screen.dart';

void main() {
  testWidgets('shows the Granite webview without a network gate',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
      ),
    );

    expect(find.text('webview: https://granite.kr/'), findsOneWidget);
    expect(find.byType(AppStartScreen), findsNothing);
  });

  testWidgets('uses the uppercase app name', (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/'),
        webViewBuilder: (context, url) => const SizedBox.shrink(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'GRANITE');
  });
}
