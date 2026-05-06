import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('assets/offline_web/index.html').readAsStringSync();
  });

  test('does not render the offline notice inside web content', () {
    expect(html, isNot(contains('class="offlineNotice"')));
    expect(html, isNot(contains('renderOfflineNotice()')));
    expect(html, isNot(contains('<header class="header">')));
    expect(html, isNot(contains('renderHeader()')));
    expect(html, isNot(contains('class="hamburger"')));
    expect(html, isNot(contains('aria-label="menu"')));
    expect(
      html,
      isNot(
        contains(
          '오프라인 상태입니다. 저장된 정보를 보여주고 있으며',
        ),
      ),
    );
  });

  test('uses the web crag list and detail class structure', () {
    expect(html, contains('class="pageBanner"'));
    expect(html, contains('class="cragListSection"'));
    expect(html, contains('class="cragDetailBanner"'));
    expect(html, contains('class="routeTable"'));
    expect(html, contains('class="routeRow"'));
    expect(html, contains('class="boulderDetailContainer"'));
    expect(html, contains('class="numberCircle"'));
    expect(html, contains('class="problemTitle"'));
  });

  test('opens a web-matching beta bottom sheet with an offline message', () {
    expect(html, contains('data-beta-button'));
    expect(html, contains('class="sheetOverlay'));
    expect(html, contains('class="sheetHandle"'));
    expect(html, contains('class="sheetTitle"'));
    expect(html, contains('현재 오프라인 상태라 베타 영상을 사용할 수 없습니다.'));
    expect(html, contains('document.body.style.overflow = \'hidden\''));
  });

  test('maps source image names to ascii-safe webview asset names', () {
    expect(html, contains('const offlineImageMap = '));
    expect(html, contains('"고물_고물_1.jpg"'));
    expect(html, contains('return offlineImageMap[fileName] ||'));
    expect(
        html, isNot(contains("split('/').map(encodeURIComponent).join('/')")));
  });

  test('keeps offline web images inside the webview readable asset folder', () {
    expect(html, isNot(contains('../offline/images/')));
    expect(html, isNot(contains('assets/offline/images/')));
    expect(html, isNot(contains('"cachedImages"')));
    expect(html, contains('"offlineImages"'));
    expect(html, isNot(contains('../images/logo.png')));
    expect(File('assets/offline_web/images/logo.png').existsSync(), true);
  });

  test('uses only ascii filenames inside the offline web image folder', () {
    final imageFiles = Directory('assets/offline_web/images')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toList();

    expect(imageFiles, isNotEmpty);
    expect(imageFiles, everyElement(matches(RegExp(r'^[\x00-\x7F]+$'))));
    expect(imageFiles, everyElement(isNot(contains('%'))));
  });

  test('registers offline web image folder as a Flutter asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('- assets/offline_web/'));
    expect(pubspec, contains('- assets/offline_web/images/'));
  });

  test('does not keep the old native-looking route and detail markup', () {
    expect(html, isNot(contains('routeFilters')));
    expect(html, isNot(contains('gradeBadge')));
    expect(html, isNot(contains('detailShell')));
    expect(html, isNot(contains('topoImageSection')));
  });
}
