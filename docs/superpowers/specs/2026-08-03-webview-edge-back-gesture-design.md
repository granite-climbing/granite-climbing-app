# WebView Edge Back Gesture Design

## Goal

Restore standard left-edge back navigation in the Granite Flutter WebView shell on iOS and Android. The gesture must navigate WebView history before leaving the app and must not introduce a custom full-screen horizontal drag that conflicts with maps, carousels, or other web interactions.

The iPhone bottom safe-area issue is explicitly outside this change.

## Current Behavior and Root Cause

`WebViewScreen` wraps the root route in `PopScope(canPop: false)` and handles attempted system pops asynchronously with `WebViewController.canGoBack()` and `goBack()`.

- On iOS, WebView back/forward navigation gestures are not enabled on the underlying `WKWebView`, so a browser-style edge swipe never enters WebView history navigation.
- On Android, the app has no explicit predictive-back manifest opt-in. The current widget test calls Flutter's synthetic `handlePopRoute()` and therefore does not verify the actual Android edge-back integration.
- The app does not retain a synchronous view of whether WebView history can go back. Predictive-back APIs require pop eligibility to be known before the gesture begins.

## Chosen Design

Use each platform's native gesture path rather than adding a Flutter `GestureDetector` over the WebView.

### iOS

Add `webview_flutter_wkwebview` as a direct dependency because the app will import its platform API. After creating the shared `WebViewController`, detect `WebKitWebViewController` and call `setAllowsBackForwardNavigationGestures(true)` before the initial request is loaded.

The underlying `WKWebView` will own the interactive back/forward transition, cancellation, and history traversal. Flutter must not add a second edge recognizer.

### Android

Opt the Flutter activity into Android's back invocation API with `android:enableOnBackInvokedCallback="true"`.

Track a synchronous `_canWebViewGoBack` state in `WebViewScreen`. Refresh it after main-frame navigation and URL changes by querying `WebViewController.canGoBack()`.

- When WebView history exists, `PopScope.canPop` is false. A committed Android back gesture is reported to `onPopInvokedWithResult`, which calls `WebViewController.goBack()`.
- When WebView history does not exist, `PopScope.canPop` is true, allowing the root Flutter route and operating system to perform their normal app-back behavior.

The existing explicit system-back handler remains the single Dart path for Android hardware back and committed edge-back gestures.

## State and Race Handling

History-state refresh is asynchronous and may complete out of order during rapid navigation. Each refresh receives a monotonically increasing generation number; only the latest completed query may update `_canWebViewGoBack`.

After `goBack()` is requested, navigation callbacks refresh the state again. If the widget has been disposed, the result is ignored.

Initial history state is false. A back attempt before the first page establishes history follows normal root-route behavior.

## Error Handling

- Failure to query `canGoBack()` must not crash the screen. The last known state is retained.
- Platform-specific iOS configuration is a no-op on Android and other platforms.
- A back attempt is handled at most once by Dart. iOS WKWebView gestures do not pass through the Android system-back handler.

## Testing

Automated tests will cover:

1. The iOS platform gesture configurator is invoked during controller setup.
2. Android/system back calls `goBack()` when WebView history exists.
3. `PopScope` allows the root route to pop when WebView history is empty.
4. URL/navigation callbacks refresh the cached history state.
5. Stale asynchronous history queries cannot overwrite a newer result.
6. The Android manifest opts into `OnBackInvokedCallback`.

The existing WebView tests must continue to pass. Verification will include Dart formatting, targeted tests, the full Flutter test suite, Flutter analysis, and `git diff --check`.

## Manual Acceptance

On an iPhone and an Android device using gesture navigation:

1. Launch the app and navigate from the home page to a detail page through an internal link.
2. Swipe inward from the left edge.
3. Confirm the WebView returns to the previous page without closing the app.
4. On iOS, confirm the transition is interactive and can be cancelled mid-swipe.
5. At the initial page with no WebView history, confirm the platform's normal app-back behavior occurs.
6. Confirm horizontal carousels and maps still receive gestures away from the system edge.
