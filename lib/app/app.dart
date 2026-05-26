import 'package:flutter/material.dart';

import '../features/webview/webview_screen.dart';

class GraniteApp extends StatelessWidget {
  const GraniteApp({
    required this.initialUrl,
    this.webViewBuilder,
    super.key,
  });

  final Uri initialUrl;
  final Widget Function(BuildContext context, Uri url)? webViewBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Granite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F312D)),
        useMaterial3: true,
      ),
      home: WebViewScreen(
        initialUrl: initialUrl,
        webViewBuilder: webViewBuilder,
      ),
    );
  }
}
