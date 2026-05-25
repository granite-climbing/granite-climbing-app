import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  testWidgets('app bottom nav uses filled icon only for the active tab',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(currentIndex: 2),
        ),
      ),
    );

    expect(_svgAsset('assets/icons/icon_record.svg'), findsOneWidget);
    expect(_svgAsset('assets/icons/icon_home_line.svg'), findsOneWidget);
    expect(_svgAsset('assets/icons/icon_project_line.svg'), findsOneWidget);
    expect(_svgAsset('assets/icons/icon_my_line.svg'), findsOneWidget);
    expect(_svgAsset('assets/icons/icon_record_line.svg'), findsNothing);
  });

  test('pubspec registers app icon assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('- assets/icons/'));
  });
}

Finder _svgAsset(String assetPath) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SvgPicture &&
        widget.bytesLoader.toString().contains(assetPath),
  );
}
