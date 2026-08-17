# iOS WebView Bottom Safe Area Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the iPhone-only empty strip below the WebView while retaining Android's bottom safe-area behavior.

**Architecture:** `WebViewFrame` keeps its existing `SafeArea` wrapper and computes only its `bottom` parameter from Flutter's target platform. The test configures each target platform explicitly, so the two policies cannot regress into one shared setting.

**Tech Stack:** Flutter, `flutter_test`.

---

### Task 1: Add platform-specific safe-area regression tests

**Files:**
- Modify: `test/features/webview/webview_screen_test.dart:13-26`

- [ ] **Step 1: Write the failing iOS assertion**

Replace the single platform-neutral test with this iOS expectation:

```dart
testWidgets('webview fills the iPhone bottom safe area', (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);

  await tester.pumpWidget(const MaterialApp(
    home: WebViewFrame(child: SizedBox.shrink()),
  ));

  final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
  expect(safeArea.top, isTrue);
  expect(safeArea.bottom, isFalse);
});
```

- [ ] **Step 2: Write the Android preservation assertion**

Add this test:

```dart
testWidgets('webview keeps the Android bottom safe area', (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);

  await tester.pumpWidget(const MaterialApp(
    home: WebViewFrame(child: SizedBox.shrink()),
  ));

  final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
  expect(safeArea.top, isTrue);
  expect(safeArea.bottom, isTrue);
});
```

- [ ] **Step 3: Run the focused test to verify the iOS assertion fails**

Run: `flutter test test/features/webview/webview_screen_test.dart`

Expected: FAIL because `WebViewFrame` currently enables `SafeArea.bottom` for every platform.

### Task 2: Implement the iOS-only WebView-frame policy

**Files:**
- Modify: `lib/features/webview/webview_screen.dart:315-318`
- Test: `test/features/webview/webview_screen_test.dart`

- [ ] **Step 1: Set `SafeArea.bottom` only for non-iOS targets**

Change `WebViewFrame.build` to:

```dart
return SafeArea(
  bottom: Theme.of(context).platform != TargetPlatform.iOS,
  child: child,
);
```

- [ ] **Step 2: Run the focused tests to verify they pass**

Run: `flutter test test/features/webview/webview_screen_test.dart`

Expected: PASS, including the iOS `bottom: false` and Android `bottom: true` checks.

### Task 3: Verify the combined mobile-shell changes

**Files:**
- Modify: `lib/features/webview/webview_screen.dart`
- Modify: `test/features/webview/webview_screen_test.dart`

- [ ] **Step 1: Format the changed Dart files**

Run: `dart format lib/features/webview/webview_screen.dart test/features/webview/webview_screen_test.dart`

- [ ] **Step 2: Run static analysis and the full test suite**

Run: `flutter analyze && flutter test`

Expected: no analysis issues and all tests pass.

- [ ] **Step 3: Verify the diff is whitespace-clean**

Run: `git diff --check`

Expected: no output and exit code 0.
