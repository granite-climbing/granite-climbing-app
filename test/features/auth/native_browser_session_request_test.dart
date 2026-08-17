import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/features/auth/native_auth_session_request.dart';

void main() {
  test('builds a WebView POST that redeems the browser handoff', () {
    final request = NativeBrowserSessionRequestBuilder(
      webBaseUrl: Uri.parse('https://granite.kr/app?old=query'),
    ).build(
      const NativeBrowserSessionRequest(
        handoff: 'encrypted.handoff+value',
        verifier: 'ios-verifier/value',
      ),
    );

    expect(
      request.url.toString(),
      'https://granite.kr/api/auth/native/browser-session',
    );
    expect(request.method, 'POST');
    expect(
      request.headers['content-type'],
      'application/x-www-form-urlencoded',
    );
    expect(Uri.splitQueryString(request.bodyText), {
      'handoff': 'encrypted.handoff+value',
      'verifier': 'ios-verifier/value',
    });
  });
}
