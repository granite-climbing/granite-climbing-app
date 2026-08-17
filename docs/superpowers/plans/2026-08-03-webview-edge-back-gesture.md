# WebView Edge Back Gesture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make WebView history respond to the native iOS edge-swipe gesture and Android system back gesture before the app itself closes.

**Architecture:** iOS delegates the interactive gesture to `WKWebView` through `WebKitWebViewController`. Android opts into the platform back-invocation API, while the existing `PopScope(canPop: false)` continues to intercept committed system-back events and routes them to WebView history before the app can close. `WebViewScreen` remains the sole owner of WebView navigation state.

**Tech Stack:** Flutter 3.41, `webview_flutter`, `webview_flutter_wkwebview`, `webview_flutter_android`, `flutter_test`.

---

### Task 1: Add failing regression coverage

**Files:**
- Modify: `test/features/webview/webview_screen_test.dart`
- Modify: `test/platform/android_screen_compatibility_test.dart`

- [ ] **Step 1: Write a failing test for the Android system-back history path**

Add to `test/features/webview/webview_screen_test.dart`:

```dart
testWidgets('system back navigates webview history after a completed page load',
    (tester) async {
  final platform = RecordingWebViewPlatform();
  WebViewPlatform.instance = platform;

  await tester.pumpWidget(MaterialApp(
    home: WebViewScreen(initialUrl: Uri.parse('https://granite.kr/')),
  ));

  platform.controller!.canGoBackResult = true;
  platform.navigationDelegate!.onPageFinished!('https://granite.kr/c/anyang');
  await tester.pump();

  await tester.binding.handlePopRoute();
  await tester.pump();

  expect(platform.controller!.goBackCount, 1);
});
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `flutter test test/features/webview/webview_screen_test.dart`

Expected: the test passes today for synthetic Flutter back routing; retain it as the regression guard while the Android manifest test demonstrates the missing device-level integration setting.

- [ ] **Step 3: Write a failing Android manifest test**

Add to `test/platform/android_screen_compatibility_test.dart`:

```dart
it('opts the Flutter activity into Android back invocation', () {
  expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
});
```

- [ ] **Step 4: Run the manifest test to verify it fails**

Run: `flutter test test/platform/android_screen_compatibility_test.dart`

Expected: FAIL because the activity has no `enableOnBackInvokedCallback` attribute.

### Task 2: Configure iOS and Android native entry points

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/webview/webview_screen.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add the iOS WebView platform package**

Add the direct dependency alongside the existing Android implementation:

```yaml
webview_flutter_wkwebview: ^3.25.1
```

- [ ] **Step 2: Enable native iOS WebView history gestures**

Import the iOS implementation and configure the underlying controller immediately after construction:

```dart
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void _enablePlatformBackForwardGestures(WebViewController controller) {
  final platformController = controller.platform;
  if (platformController is WebKitWebViewController) {
    unawaited(platformController.setAllowsBackForwardNavigationGestures(true));
  }
}
```

Call `_enablePlatformBackForwardGestures(controller);` before `loadRequest`. The function is a no-op for Android and test platforms.

- [ ] **Step 3: Opt Android into the back-invocation API**

Add the attribute to the existing `MainActivity` declaration without changing the user's Apple callback edit:

```xml
android:enableOnBackInvokedCallback="true"
```

- [ ] **Step 4: Run the manifest test to verify it passes**

Run: `flutter test test/platform/android_screen_compatibility_test.dart`

Expected: PASS.

### Task 3: Format and verify the focused change

**Files:**
- Modify: files from Tasks 1-2 only

- [ ] **Step 1: Format changed Dart files**

Run: `dart format lib/features/webview/webview_screen.dart test/features/webview/webview_screen_test.dart test/platform/android_screen_compatibility_test.dart`

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`

Expected: no analysis issues.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 4: Verify the diff is whitespace-clean and scoped**

Run: `git diff --check && git diff -- lib/features/webview/webview_screen.dart test/features/webview/webview_screen_test.dart test/platform/android_screen_compatibility_test.dart android/app/src/main/AndroidManifest.xml pubspec.yaml pubspec.lock`

Expected: no whitespace errors; the Android manifest preserves the existing Apple callback edit.
