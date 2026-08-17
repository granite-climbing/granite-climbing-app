# iOS Kakao System OAuth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace build 25's iOS Kakao Account SDK request with an `ASWebAuthenticationSession` REST OAuth flow that exposes Kakao's mobile login page and establishes the existing Granite WebView session.

**Architecture:** Extend Granite's existing REST OAuth start and callback routes with an additive `ios-system-auth` surface. The callback returns an encrypted, two-minute, verifier-bound handoff to a fixed custom scheme; the Flutter app redeems it through a WebView form POST so the existing HttpOnly session cookie persists across relaunches. Android, older apps, other providers, and account policy remain unchanged.

**Tech Stack:** Next.js 15 route handlers, TypeScript, `jose`, Vitest, Flutter, Dart, `flutter_web_auth_2`, `crypto`, WKWebView, `ASWebAuthenticationSession`, CocoaPods, Xcode signing.

---

### Task 1: Add an iOS system-auth OAuth state and Kakao prompt

**Files:**
- Modify: `/Users/scorchedrice/granite/granite-v2/lib/auth/oauth/types.ts`
- Modify: `/Users/scorchedrice/granite/granite-v2/lib/auth/oauth/state.ts`
- Modify: `/Users/scorchedrice/granite/granite-v2/lib/auth/oauth/state.test.ts`
- Modify: `/Users/scorchedrice/granite/granite-v2/lib/auth/oauth/providers.ts`
- Modify: `/Users/scorchedrice/granite/granite-v2/lib/auth/oauth/providers.test.ts`
- Modify: `/Users/scorchedrice/granite/granite-v2/app/api/auth/start/[provider]/route.ts`
- Modify: `/Users/scorchedrice/granite/granite-v2/app/api/auth/start/[provider]/route.test.ts`

- [ ] **Step 1: Write failing state, provider URL, and route tests**

Add tests that require:

```ts
expect(createOAuthState({
  provider: "kakao",
  returnTo: "/me",
  surface: "ios-system-auth",
  handoffChallenge: "a".repeat(43)
})).toMatchObject({
  surface: "ios-system-auth",
  handoffChallenge: "a".repeat(43)
});
```

```ts
expect(buildAuthorizationUrl("kakao", {
  redirectUri: "https://v2.granite.kr/api/auth/callback/kakao",
  state: "state-value",
  nonce: "nonce-value",
  prompt: "login"
}).searchParams.get("prompt")).toBe("login");
```

For `GET /api/auth/start/kakao?native_system_auth=ios&handoff_challenge=<43 base64url characters>&returnTo=/me`, assert that the Kakao redirect has `prompt=login` and the OAuth state cookie contains `surface: "ios-system-auth"` and the challenge. Also assert that an invalid challenge redirects to `/login?error=invalid_native_auth_request` and ordinary web OAuth has no `prompt` parameter.

- [ ] **Step 2: Run the focused web tests and verify RED**

Run from `/Users/scorchedrice/granite/granite-v2`:

```bash
pnpm test -- lib/auth/oauth/state.test.ts lib/auth/oauth/providers.test.ts 'app/api/auth/start/[provider]/route.test.ts'
```

Expected: FAIL because the new surface, challenge, and prompt input do not exist.

- [ ] **Step 3: Implement the minimum state and start-route support**

Extend `OAuthSurface` to:

```ts
export type OAuthSurface = "web" | "flutter-webview" | "ios-system-auth";
```

Add an optional `handoffChallenge` to state creation and schema, accepting only `/^[A-Za-z0-9_-]{43}$/`. Extend authorization URL input with `prompt?: "login"`, and add it only for Kakao. In the start route, recognize `native_system_auth=ios` only for Kakao with a valid challenge; create the iOS state and pass `prompt: "login"`. Reject malformed native-system requests instead of silently downgrading them.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the Step 2 command.

Expected: all focused tests pass, including unchanged ordinary web and legacy native-fallback cases.

- [ ] **Step 5: Commit the web OAuth start contract**

```bash
git add lib/auth/oauth/types.ts lib/auth/oauth/state.ts lib/auth/oauth/state.test.ts \
  lib/auth/oauth/providers.ts lib/auth/oauth/providers.test.ts \
  'app/api/auth/start/[provider]/route.ts' 'app/api/auth/start/[provider]/route.test.ts'
git diff --cached --check
git commit -m "feat: add iOS Kakao system OAuth start"
```

### Task 2: Add encrypted native-browser handoffs

**Files:**
- Create: `/Users/scorchedrice/granite/granite-v2/lib/auth/native-browser-handoff.ts`
- Create: `/Users/scorchedrice/granite/granite-v2/lib/auth/native-browser-handoff.test.ts`

- [ ] **Step 1: Write failing handoff tests**

Cover all three existing account-resolution outputs with a discriminated payload:

```ts
const token = await createNativeBrowserHandoff({
  kind: "session",
  userId: "user_1",
  returnTo: "/me",
  challenge: "a".repeat(43)
});

await expect(readNativeBrowserHandoff(token)).resolves.toEqual({
  kind: "session",
  userId: "user_1",
  returnTo: "/me",
  challenge: "a".repeat(43)
});
```

Also test signup and recovery payloads, tampering, expiration with a supplied clock, invalid token type, and challenge generation:

```ts
expect(createNativeBrowserChallenge("verifier-value")).toMatch(/^[A-Za-z0-9_-]{43}$/);
```

- [ ] **Step 2: Run the handoff test and verify RED**

```bash
pnpm test -- lib/auth/native-browser-handoff.test.ts
```

Expected: FAIL because the module does not exist.

- [ ] **Step 3: Implement authenticated encryption and verification**

Use `EncryptJWT` and `jwtDecrypt` from `jose` with:

```ts
const HANDOFF_TYPE = "granite-native-browser-handoff+jwt";
const HANDOFF_ISSUER = "granite-v2";
const HANDOFF_AUDIENCE = "granite-ios";
const HANDOFF_TTL_SECONDS = 120;
```

Derive a 32-byte `A256GCM` direct-encryption key with SHA-256 over a domain-separated form of the existing session secret. Set `alg: "dir"`, `enc: "A256GCM"`, the dedicated type, issuer, audience, issued-at, and expiration. Validate decrypted payloads with `zod`; never return raw `JWTPayload`. Implement the challenge as base64url SHA-256 of the UTF-8 verifier.

- [ ] **Step 4: Run the handoff tests and verify GREEN**

Run the Step 2 command.

Expected: all handoff tests pass.

- [ ] **Step 5: Commit the handoff primitive**

```bash
git add lib/auth/native-browser-handoff.ts lib/auth/native-browser-handoff.test.ts
git diff --cached --check
git commit -m "feat: add encrypted native browser handoff"
```

### Task 3: Return OAuth results to iOS and redeem them in the WebView

**Files:**
- Modify: `/Users/scorchedrice/granite/granite-v2/app/api/auth/callback/[provider]/route.ts`
- Modify: `/Users/scorchedrice/granite/granite-v2/app/api/auth/callback/[provider]/route.test.ts`
- Create: `/Users/scorchedrice/granite/granite-v2/app/api/auth/native/browser-session/route.ts`
- Create: `/Users/scorchedrice/granite/granite-v2/app/api/auth/native/browser-session/route.test.ts`

- [ ] **Step 1: Write failing callback tests**

For valid Kakao OAuth state with `surface: "ios-system-auth"` and a valid challenge, cover the existing `session`, `signup`, and `recover` resolution results. Assert that each callback redirects to:

```text
graniteclimbing://oauth/kakao?handoff=<opaque encrypted value>
```

Assert that it does not set `granite_session`, pending-signup, or pending-recovery cookies in the system authentication session. Decrypt the returned handoff in the test and verify it represents the unchanged resolution result. Keep the existing browser callback tests unchanged.

- [ ] **Step 2: Write failing browser-session redemption tests**

POST `handoff` and `verifier` as form data. For a session handoff, assert the response sets `granite_session` and redirects to `/me`. For signup and recovery handoffs, assert the existing pending cookie and route are preserved. Add negative tests for malformed form data, expired or tampered tokens, and challenge mismatch; each must redirect to `/login?error=native_browser_session_failed` without auth cookies.

- [ ] **Step 3: Run the callback and redemption tests and verify RED**

```bash
pnpm test -- 'app/api/auth/callback/[provider]/route.test.ts' \
  app/api/auth/native/browser-session/route.test.ts
```

Expected: FAIL because system-auth callback branching and the redemption route do not exist.

- [ ] **Step 4: Implement callback handoff creation**

After `resolveOAuthLogin`, branch only when `state.surface === "ios-system-auth"`. Convert the existing resolution to the matching encrypted handoff payload and redirect to the fixed `graniteclimbing://oauth/kakao` URL. Do not accept a callback URL from the request. Provider failures after valid iOS state should return the fixed callback with a safe `error` value so the authentication session can close.

- [ ] **Step 5: Implement browser-session redemption**

The new POST route must:

1. Read string `handoff` and `verifier` form fields.
2. Decrypt and validate the handoff.
3. Compute the verifier challenge and require an exact match.
4. Reuse `createUserSessionToken`, `createPendingSignupToken`, or `createPendingRecoveryToken` and their existing cookie options.
5. Redirect to the handoff's sanitized return path for sessions, `/signup` for signup, and `/recover` for recovery.
6. Return the safe login error redirect without cookies on any failure.

- [ ] **Step 6: Run the callback and redemption tests and verify GREEN**

Run the Step 3 command.

Expected: all new tests and all existing callback tests pass.

- [ ] **Step 7: Run the complete web verification gate**

```bash
pnpm typecheck
pnpm test
pnpm build
git diff --check
```

Expected: typecheck, all Vitest tests, and the production Next.js build pass.

- [ ] **Step 8: Commit the web callback and redemption flow**

```bash
git add 'app/api/auth/callback/[provider]/route.ts' \
  'app/api/auth/callback/[provider]/route.test.ts' \
  app/api/auth/native/browser-session/route.ts \
  app/api/auth/native/browser-session/route.test.ts
git diff --cached --check
git commit -m "feat: bridge Kakao web OAuth into the app"
```

### Task 4: Add the iOS Kakao system OAuth client

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/features/auth/kakao_system_oauth_client.dart`
- Create: `test/features/auth/kakao_system_oauth_client_test.dart`
- Modify: `ios/Runner/Info.plist`
- Modify: `test/platform/kakao_native_config_test.dart`

- [ ] **Step 1: Write failing client tests**

Inject a deterministic verifier and a recording authenticator. Assert that login opens:

```text
https://v2.granite.kr/api/auth/start/kakao?returnTo=%2Fme&native_system_auth=ios&handoff_challenge=<43-character challenge>
```

with callback scheme `graniteclimbing`, accepts only `graniteclimbing://oauth/kakao?handoff=...`, returns the handoff plus original verifier, maps an `error=access_denied` callback to cancellation, and rejects wrong schemes, hosts, paths, or empty handoffs.

Add a platform config assertion that `Info.plist` contains the `graniteclimbing` URL scheme.

- [ ] **Step 2: Run the focused Flutter tests and verify RED**

```bash
flutter test test/features/auth/kakao_system_oauth_client_test.dart \
  test/platform/kakao_native_config_test.dart
```

Expected: FAIL because the client and callback scheme do not exist.

- [ ] **Step 3: Add dependencies and implement the client**

Add current stable direct dependencies:

```yaml
flutter_web_auth_2: ^5.0.0
crypto: ^3.0.6
```

Implement a focused client with injected authentication launcher and verifier factory. The production launcher calls:

```dart
FlutterWebAuth2.authenticate(
  url: startUrl.toString(),
  callbackUrlScheme: 'graniteclimbing',
);
```

Generate 32 random bytes with `Random.secure()`, encode a base64url verifier without padding, hash the verifier with SHA-256, and encode the challenge without padding. Sanitize `returnTo` to a single-leading-slash path, defaulting to `/me`. Parse and strictly validate the callback before returning a `KakaoSystemOAuthHandoff(token, verifier)`.

- [ ] **Step 4: Register the iOS callback scheme**

Add a dedicated `CFBundleURLTypes` entry containing:

```xml
<string>graniteclimbing</string>
```

Do not change existing Kakao, Naver, or Google schemes.

- [ ] **Step 5: Refresh dependencies and verify GREEN**

```bash
flutter pub get
flutter test test/features/auth/kakao_system_oauth_client_test.dart \
  test/platform/kakao_native_config_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 6: Commit the iOS system OAuth client**

```bash
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist \
  lib/features/auth/kakao_system_oauth_client.dart \
  test/features/auth/kakao_system_oauth_client_test.dart \
  test/platform/kakao_native_config_test.dart
git diff --cached --check
git commit -m "feat: open Kakao REST OAuth on iOS"
```

### Task 5: Route iOS Kakao results into the WebView session

**Files:**
- Modify: `lib/features/auth/native_social_login_service.dart`
- Modify: `lib/features/auth/kakao_native_login_service.dart`
- Modify: `lib/features/auth/native_auth_session_request.dart`
- Modify: `lib/data/bridge/handlers/native_auth_bridge_handler.dart`
- Modify: `test/features/auth/kakao_native_login_service_test.dart`
- Create: `test/features/auth/native_auth_session_request_test.dart`
- Modify: `test/data/bridge/handlers/native_auth_bridge_handler_test.dart`
- Modify: `test/features/webview/webview_screen_test.dart`

- [ ] **Step 1: Write failing iOS routing tests**

Inject an iOS platform decision and a recording system OAuth client. For Kakao `account` mode, assert the service returns a browser handoff and never calls `loginWithKakaoAccount`. Inject a non-iOS decision and assert the current Android SDK behavior remains unchanged. Assert system-sheet cancellation maps to `NativeSocialLoginCanceledException`.

- [ ] **Step 2: Write failing WebView redemption request tests**

Require a browser handoff result to produce:

```text
POST https://v2.granite.kr/api/auth/native/browser-session
content-type: application/x-www-form-urlencoded
handoff=<encoded>&verifier=<encoded>
```

Assert the bridge loads that POST and does not call `/api/auth/native/session`. Preserve the existing native access-token tests.

- [ ] **Step 3: Run the focused tests and verify RED**

```bash
flutter test test/features/auth/kakao_native_login_service_test.dart \
  test/features/auth/native_auth_session_request_test.dart \
  test/data/bridge/handlers/native_auth_bridge_handler_test.dart \
  test/features/webview/webview_screen_test.dart
```

Expected: FAIL because native social results cannot carry browser handoffs and the handler has no redemption builder.

- [ ] **Step 4: Add a typed browser handoff result**

Add `NativeBrowserSessionHandoff` with required `token` and `verifier`. Extend `NativeSocialLoginResult` so exactly one credential form is present: a non-empty native access token or a browser handoff. Keep `idToken` only on native credentials.

- [ ] **Step 5: Switch only iOS account-mode Kakao login**

Inject `KakaoSystemOAuthClient` and a testable `isIOS` provider into `KakaoNativeLoginService`. When mode is `account` and `isIOS()` is true, call the system client with the request's return path and return a browser handoff. Leave the current Talk-preferred and Android account SDK branches byte-for-byte equivalent in behavior.

- [ ] **Step 6: Add the browser-session POST builder and handler branch**

Build the redemption form with only `handoff` and `verifier`. In `NativeAuthBridgeHandler`, choose the browser-session builder when the result contains a handoff; otherwise keep using `NativeAuthSessionRequestBuilder`. Pass both through the existing `loadSessionRequest` callback so the response cookie is written in WKWebView.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run the Step 3 command.

Expected: iOS handoff, Android preservation, cancellation, native token session, and WebView redemption tests all pass.

- [ ] **Step 8: Commit iOS routing and session redemption**

```bash
git add lib/features/auth/native_social_login_service.dart \
  lib/features/auth/kakao_native_login_service.dart \
  lib/features/auth/native_auth_session_request.dart \
  lib/data/bridge/handlers/native_auth_bridge_handler.dart \
  test/features/auth/kakao_native_login_service_test.dart \
  test/features/auth/native_auth_session_request_test.dart \
  test/data/bridge/handlers/native_auth_bridge_handler_test.dart \
  test/features/webview/webview_screen_test.dart
git diff --cached --check
git commit -m "feat: redeem iOS Kakao browser sessions"
```

### Task 6: Prepare build 26, deploy server support, and validate IPA

**Files:**
- Modify: `pubspec.yaml`
- Modify: `test/platform/ios_release_config_test.dart`
- Generated and inspect: `ios/Podfile.lock`
- Build artifact: `build/ios/ipa/GRANITE.ipa`

- [ ] **Step 1: Write the failing build-number expectation**

Change the release contract test to require:

```dart
expect(pubspec, contains('version: 1.1.2+26'));
```

- [ ] **Step 2: Run the release test and verify RED**

```bash
flutter test test/platform/ios_release_config_test.dart
```

Expected: FAIL because the source still declares build 25.

- [ ] **Step 3: Set build 26 and refresh CocoaPods**

Change only:

```yaml
version: 1.1.2+26
```

Then run:

```bash
flutter pub get
cd ios && pod install && cd ..
```

Inspect generated changes and retain the deployment target at iOS 15.0.

- [ ] **Step 4: Verify GREEN and commit release metadata**

```bash
flutter test test/platform/ios_release_config_test.dart
git add pubspec.yaml test/platform/ios_release_config_test.dart ios/Podfile.lock
git diff --cached --check
git commit -m "chore: prepare iOS 1.1.2 build 26"
```

- [ ] **Step 5: Run both complete verification gates**

From `/Users/scorchedrice/granite/granite-v2`:

```bash
pnpm typecheck
pnpm test
pnpm build
git diff --check
git status --short --branch
```

From the Flutter release worktree:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
git status --short --branch
```

Expected: every command passes; only the pre-existing ignored or untracked `.hermes/` directory remains outside committed web changes.

- [ ] **Step 6: Push additive web support to production**

```bash
git push origin main
```

Verify `https://v2.granite.kr/healthz` remains healthy. Do not send a live OAuth request with production user credentials from automation.

- [ ] **Step 7: Build the signed IPA**

From the Flutter release worktree, use the existing ignored production environment file without copying its contents:

```bash
FLUTTER_GRANITE_ENV_FILE=/Users/scorchedrice/granite/granite-climbing-app/config/prod.env \
  tool/flutter_granite.sh build ipa --env prod
```

Expected: Xcode archives and exports one App Store Connect IPA.

- [ ] **Step 8: Validate the IPA**

Expand the IPA into a temporary directory and verify:

```text
CFBundleIdentifier = com.granite.climbing
CFBundleShortVersionString = 1.1.2
CFBundleVersion = 26
MinimumOSVersion = 15.0
```

Run `codesign --verify --deep --strict`, record `shasum -a 256`, and confirm the source worktree remains clean.

- [ ] **Step 9: Report manual TestFlight checks**

Provide the IPA path and checksum. State that final acceptance requires the user's real-device checks: Kakao Talk button visible in the system sheet, both Kakao paths return to the app, WebView is logged in, force-quit preserves login, cancellation restores the button, and logout persists across relaunch.
