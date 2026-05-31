# App Store Korean Language And Auth Bridge Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the shipped WebView shell for Korean App Store metadata alignment and future Granite v2 social-login bridge changes without introducing native navigation UI.

**Architecture:** Keep Flutter as a thin WebView shell while exposing a stable bridge contract to the web app. The iOS binary default language is aligned to Korean, and the auth bridge accepts richer web login requests while failing safely when native auth/session handoff is not ready.

**Tech Stack:** Flutter, Dart, webview_flutter, iOS Xcode project metadata, flutter_test.

---

### Task 1: Korean iOS Binary Defaults

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Test: `test/platform/ios_localization_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('iOS Runner project defaults to Korean localization', () {
  final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  expect(project, contains('developmentRegion = ko;'));
  expect(project, contains('knownRegions = ('));
  expect(project, contains('ko,'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/platform/ios_localization_test.dart`

Expected: FAIL because the project currently has `developmentRegion = en;` and no `ko` region.

- [ ] **Step 3: Write minimal implementation**

Change the Xcode project to `developmentRegion = ko;` and include `ko` in `knownRegions`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/platform/ios_localization_test.dart`

Expected: PASS.

### Task 2: Auth Bridge Request Compatibility

**Files:**
- Modify: `lib/features/auth/native_auth_service.dart`
- Modify: `lib/data/bridge/handlers/auth_bridge_handler.dart`
- Test: `test/data/bridge/handlers/auth_bridge_handler_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
test('passes provider and surface hints from web login requests to native auth', () async {
  final authService = RecordingNativeAuthService(
    const NativeLoginStart(provider: 'kakao'),
  );
  final sender = RecordingBridgeSender();
  final handler = AuthBridgeHandler(
    authService: authService,
    sessionHandoffService: RecordingSessionHandoffService(
      const SessionHandoff(handoffCode: 'handoff-1'),
    ),
  );

  await handler.handle(
    const BridgeMessage(
      version: 1,
      id: 'login-1',
      type: 'auth.login.requested',
      direction: BridgeDirection.webToNative,
      payload: {
        'provider': 'kakao',
        'surface': 'flutter-webview',
        'returnTo': '/me',
      },
    ),
    sender,
  );

  expect(authService.requests.single.providerHint, 'kakao');
  expect(authService.requests.single.surface, 'flutter-webview');
});
```

```dart
test('responds with auth.login.failed when native login cannot start', () async {
  final sender = RecordingBridgeSender();
  final handler = AuthBridgeHandler(
    authService: ThrowingNativeAuthService(),
  );

  await handler.handle(
    const BridgeMessage(
      version: 1,
      id: 'login-1',
      type: 'auth.login.requested',
      direction: BridgeDirection.webToNative,
    ),
    sender,
  );

  expect(sender.messages.single.type, 'auth.login.failed');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/bridge/handlers/auth_bridge_handler_test.dart`

Expected: FAIL because `NativeLoginRequest` does not yet expose provider/surface hints and auth failures are not converted to bridge messages.

- [ ] **Step 3: Write minimal implementation**

Add `providerHint` and `surface` to `NativeLoginRequest`; read those fields from bridge payload; wrap native login/session handoff in try/catch and send `auth.login.failed` or `auth.session.sync.failed`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/bridge/handlers/auth_bridge_handler_test.dart`

Expected: PASS.

### Task 3: Full Verification

**Files:**
- All changed files

- [ ] **Step 1: Format**

Run: `dart format lib test`

Expected: No formatting errors.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`

Expected: No issues.

- [ ] **Step 3: Test**

Run: `flutter test`

Expected: All tests pass.

- [ ] **Step 4: Diff check**

Run: `git diff --check`

Expected: No whitespace errors.
