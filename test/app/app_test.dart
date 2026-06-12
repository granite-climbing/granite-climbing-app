import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/app/app.dart';

void main() {
  testWidgets('starts with the Granite webview at the app entry URL',
      (tester) async {
    await tester.pumpWidget(
      GraniteApp(
        initialUrl: Uri.parse('https://granite.kr/app'),
        webViewBuilder: (context, url) => Scaffold(
          body: Text('webview: $url'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('webview: https://granite.kr/app'), findsOneWidget);
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
