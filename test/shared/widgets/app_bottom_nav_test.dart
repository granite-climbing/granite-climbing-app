import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/shared/widgets/app_bottom_nav.dart';

void main() {
  testWidgets('app bottom nav renders the Granite app shell tabs',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(),
        ),
      ),
    );

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('프로젝트'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);

    final homeText = tester.widget<Text>(find.text('홈'));
    final projectText = tester.widget<Text>(find.text('프로젝트'));
    expect(homeText.style?.color, const Color(0xFF090909));
    expect(projectText.style?.color, const Color(0xFFB8B8B8));
  });

  test('pubspec registers app icon assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('- assets/icons/'));
  });
}
