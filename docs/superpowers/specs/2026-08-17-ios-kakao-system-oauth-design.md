# iOS Kakao System OAuth Design

## Goal

Replace only the iOS Kakao authentication entry point with a system authentication session that opens Granite's existing Kakao REST OAuth flow. The Kakao-hosted page must offer the mobile Kakao Talk login path alongside Kakao Account input when Kakao makes that option available. After authentication, the app must establish the same Granite web session cookie currently used by the main WebView.

## Scope

- Apply the new flow only to Kakao login on iOS.
- Keep Android Kakao login behavior unchanged.
- Keep Naver, Google, and Apple login behavior unchanged.
- Keep existing account resolution, signup, recovery, logout, and session policy unchanged.
- Preserve behavior for app versions that do not understand the new flow.
- Produce the next TestFlight artifact as `1.1.2+26` after verification.

## Current behavior

The deployed web login page sends a Kakao native bridge request with `loginMode: account`. Build 25 handles that request with `loginWithKakaoAccount(prompts: [Prompt.login])`. This opens a system browser sheet but explicitly chooses the Kakao Account reauthentication path. Kakao therefore does not guarantee the Kakao Talk login button shown by a mobile REST OAuth authorization page.

The app then sends the Kakao access token to `/api/auth/native/session` inside the main WebView. That endpoint creates the Granite `granite_session` cookie, so the WebView remains logged in across app restarts.

## Chosen approach

Use `flutter_web_auth_2` on iOS. The plugin presents `ASWebAuthenticationSession`, which is the system OAuth surface visible in the reference app. It opens an additive native-browser mode on Granite's existing `/api/auth/start/kakao` REST OAuth endpoint. This mode adds Kakao's `prompt=login` parameter so the authentication page is shown even when the system browser has a Kakao cookie; unlike the native account SDK path, Kakao's REST authorization page can still expose its Kakao Talk login button. The normal Kakao redirect URI and token exchange remain on the server.

The authorization session and the main WKWebView have separate cookie stores. A direct OAuth success cookie in the authorization session would not log in the main WebView. The server therefore returns a short-lived encrypted handoff token to a fixed app callback scheme. The app submits that token back through the main WebView, where the server establishes the existing Granite cookie and redirects to the requested in-app page.

## App flow

1. The deployed login page sends the existing Kakao bridge message.
2. On iOS, the Kakao service generates a cryptographically random verifier and a SHA-256 challenge.
3. The app launches `ASWebAuthenticationSession` at `/api/auth/start/kakao` with the sanitized return path, an iOS system-auth marker, and the challenge. The server adds `prompt=login` only for this REST OAuth surface.
4. Kakao authenticates the user through the mobile REST OAuth page.
5. Granite's OAuth callback exchanges the authorization code and runs the existing account-resolution logic.
6. For the iOS system-auth surface, the callback packages the existing resolution result, return path, challenge, and a short expiry into an encrypted handoff token.
7. The callback redirects to `graniteclimbing://oauth/kakao?handoff=...`, closing the system sheet and returning control to the app.
8. The app validates the callback scheme, host, path, and required token. It then loads a form POST to `/api/auth/native/browser-session` in the main WebView with the handoff token and verifier.
9. The server decrypts the handoff, checks expiry and challenge binding, applies the same session or pending-flow cookie that the existing OAuth callback would apply, and redirects within the WebView.

On Android, the Kakao service continues to use the current Kakao Flutter SDK path. Older apps continue to ignore the bridge's login mode or use their existing native flow; the new server parameters and endpoints are additive.

## Security

- The app callback is fixed to `graniteclimbing://oauth/kakao`; the server never accepts an arbitrary callback URL.
- OAuth state remains random and bound to the authorization-session cookie.
- The handoff is encrypted and authenticated with a key derived from the existing server session secret, so URL contents do not expose provider tokens, user data, or Granite session tokens.
- The handoff expires after two minutes and has a dedicated token type.
- The handoff contains the SHA-256 challenge. Redemption requires the verifier retained only by the app, preventing another app that intercepts the custom-scheme callback from redeeming it.
- The WebView redemption endpoint accepts only form POST requests and never places the verifier or resulting Granite session in a redirect URL.
- Logs and bridge diagnostics must not include the handoff token, verifier, provider token, or session cookie.

## Error and cancellation behavior

- Closing the iOS authentication sheet maps to the existing native-login cancellation result and leaves the login page usable.
- Invalid callback URLs, missing handoffs, expired handoffs, challenge mismatches, and decryption failures map to the existing safe login-failure response.
- Kakao OAuth errors return through the fixed app callback without raw provider diagnostics.
- The login button's pending state is cleared by the existing native bridge failure message.
- Existing browser and native OAuth routes retain their current error behavior.

## Session persistence

The final WebView response sets the same `granite_session` HttpOnly cookie with the existing 30-day policy. No new client-side session store is introduced. Once redemption succeeds, force-closing and reopening the app must retain login exactly as before. Logout continues to clear the same cookie.

## Testing

### Web

- Native-browser OAuth start accepts only the Kakao provider, fixed iOS surface, valid challenge, and sanitized return path.
- Native-browser Kakao authorization includes `prompt=login`; ordinary web authorization URLs remain unchanged.
- OAuth state preserves the iOS surface and challenge.
- Kakao callback returns the fixed custom-scheme URL with an opaque handoff instead of a browser cookie for the iOS surface.
- Handoff encryption/decryption, expiry, type, and challenge verification are covered independently.
- Browser-session redemption sets the existing session cookie and redirects to the sanitized return path.
- Invalid or mismatched handoffs fail without setting authentication cookies.
- Existing web OAuth and native token session tests remain unchanged and passing.

### Flutter

- iOS account-mode Kakao requests launch the system OAuth client instead of `loginWithKakaoAccount`.
- Android and non-account Kakao paths retain current SDK behavior.
- Start URLs contain only the expected surface, return path, and challenge.
- Callback validation rejects incorrect schemes, hosts, paths, and missing handoffs.
- Cancellation and malformed callbacks map to existing cancellation/failure behavior.
- Handoff results create a WebView form POST to the browser-session endpoint without logging secrets.
- Info.plist registers the fixed callback scheme.
- Full formatting, analysis, and test suites pass before creating build 26.

### TestFlight acceptance

- The iOS system authentication popup appears.
- The Kakao mobile REST OAuth page matches the reference flow and shows the Kakao Talk login option when Kakao deems it available.
- Kakao Talk and Kakao Account authentication both return to the app.
- The main WebView is logged in after the popup closes.
- Force-closing and reopening the app preserves login.
- Canceling the popup returns to an enabled login screen.
- Logout followed by relaunch remains logged out.

## Rollout

Server support is deployed before build 26 is tested. The server changes are additive and do not change the payload understood by older apps. Build 25 and earlier therefore keep their existing Kakao SDK behavior. Build 26 switches only the iOS account-mode Kakao request to the system REST OAuth path. Android remains on the existing native SDK flow until a separate decision is made.
