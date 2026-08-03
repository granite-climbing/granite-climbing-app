# iOS WebView Bottom Safe Area Design

## Goal

Remove the empty area below the embedded WebView on iPhones without changing Android layout behavior.

## Root Cause

`WebViewFrame` currently uses `SafeArea` with its default `bottom: true`. On an iPhone with a home indicator, Flutter reduces the WebView's frame by the bottom safe-area inset and exposes the parent `Scaffold` background below it. The website itself is not the source of the gap.

The regression was introduced when commit `3097bfc` removed the prior `bottom: false` setting from `WebViewFrame`.

## Design

`WebViewFrame` will choose its bottom safe-area behavior by the Flutter target platform:

- iOS: use `SafeArea(bottom: false)` so the WebView reaches the bottom edge.
- Android: retain `SafeArea(bottom: true)` exactly as it behaves today.
- Other targets: retain the current safe-area behavior.

The WebView, website CSS, Android widget layout, and loading/error screens are not changed.

## Testing

Widget tests will explicitly override the target platform and assert:

1. iOS disables only the bottom safe-area inset.
2. Android continues to enable the bottom safe-area inset.

Verification will run the focused WebView widget tests, Flutter analysis, the full Flutter test suite, and a whitespace diff check.
