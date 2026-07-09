# v2 WebView demo bridge toggle

Date: 2026-07-10

Context: The v2 web login page falls back to native login whenever `window.FlutterWebView` exists. The current Android shell does not have production-ready native social login configured for the v2 domain, so login attempts in a `https://v2.granite.kr/` WebView can redirect to `/login?error=native_login_failed`.

Temporary demo decision: build the Android demo APK with `GRANITE_ENABLE_WEBVIEW_BRIDGE=false`. This prevents the app from exposing the `FlutterWebView` JavaScript channel, so the unchanged v2 web login page uses its normal web OAuth form submit path.

Demo command:

```bash
flutter run --release -d emulator-5554 \
  --dart-define=GRANITE_WEB_URL=https://v2.granite.kr/ \
  --dart-define=GRANITE_ENABLE_WEBVIEW_BRIDGE=false
```

Play closed testing upload: use an AAB with app version `0.0.4+14`. Version code `13` was already used in Play Console, so the demo upload uses version code `14`.

Direct APK rebuild: because the previously shared APK could be confused with an older attachment, the next direct APK rebuild uses app version `0.0.4+15` and should be shared with a filename that includes `v2` and `+15`.

Android navigation bar fix: direct APK rebuild `0.0.4+16` keeps the WebView inside the bottom safe area so the web bottom tab is not covered by Android system navigation controls.

Public testing AAB rebuild: `0.0.4+16` includes the same v2 WebView URL, disabled bridge, and Android navigation bar SafeArea fix for Google Play testing upload.

iOS TestFlight IPA rebuild: `0.0.4+16` includes the same v2 WebView URL, disabled bridge, and shared Flutter SafeArea fix.

Expected trade-off: all app bridge features are disabled for this demo build, including native social login, native share, native external navigation requests, and native session sync. Regular WebView browsing still works.

Follow-up: replace this workaround with a web-side capability check so native login is used only after the app advertises `auth.native` in `app.native.ready`.
