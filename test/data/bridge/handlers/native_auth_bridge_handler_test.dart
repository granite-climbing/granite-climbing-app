import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/native_auth_bridge_handler.dart';
import 'package:granite_climbing_app/features/auth/native_auth_diagnostics.dart';
import 'package:granite_climbing_app/features/auth/native_auth_session_request.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';

void main() {
  test('native auth bridge loads a WebView POST session request', () async {
    final loginService = FakeNativeSocialLoginService(
      result: const NativeSocialLoginResult(
        provider: 'google',
        accessToken: 'token-1',
        idToken: 'id-token-1',
      ),
    );
    final loader = RecordingUrlLoader();
    final sessionLoader = RecordingSessionRequestLoader();
    final handler = NativeAuthBridgeHandler(
      loginService: loginService,
      loadUrl: loader.load,
      loadSessionRequest: sessionLoader.load,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

    await handler.handle(
      const BridgeMessage(
        version: 1,
        id: 'native-login-1',
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'provider': 'google',
          'returnTo': '/me',
        },
      ),
      RecordingBridgeSender(),
    );

    expect(loginService.requests.single.provider, 'google');
    expect(loginService.requests.single.returnTo, '/me');
    expect(loader.urls, isEmpty);
    final request = sessionLoader.requests.single;
    expect(
        request.url.toString(), 'https://granite.kr/api/auth/native/session');
    expect(request.method, 'POST');
    expect(
        request.headers['content-type'], 'application/x-www-form-urlencoded');
    expect(Uri.splitQueryString(request.bodyText), {
      'provider': 'google',
      'accessToken': 'token-1',
      'idToken': 'id-token-1',
      'returnTo': '/me',
    });
  });

  test('passes Kakao account login mode to the native login service', () async {
    final loginService = FakeNativeSocialLoginService(
      result: const NativeSocialLoginResult(
        provider: 'kakao',
        accessToken: 'kakao-token',
      ),
    );
    final handler = NativeAuthBridgeHandler(
      loginService: loginService,
      loadSessionRequest: RecordingSessionRequestLoader().load,
    );

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'provider': 'kakao',
          'loginMode': 'account',
        },
      ),
      RecordingBridgeSender(),
    );

    expect(
      loginService.requests.single.loginMode,
      NativeSocialLoginMode.account,
    );
  });

  test('defaults missing and invalid Kakao login modes to talk preferred',
      () async {
    for (final value in <Object?>[null, 'unsupported']) {
      final loginService = FakeNativeSocialLoginService(
        result: const NativeSocialLoginResult(
          provider: 'kakao',
          accessToken: 'kakao-token',
        ),
      );
      final handler = NativeAuthBridgeHandler(
        loginService: loginService,
        loadSessionRequest: RecordingSessionRequestLoader().load,
      );

      await handler.handle(
        BridgeMessage(
          version: 1,
          type: 'auth.native.login.requested',
          direction: BridgeDirection.webToNative,
          payload: {
            'provider': 'kakao',
            if (value != null) 'loginMode': value,
          },
        ),
        RecordingBridgeSender(),
      );

      expect(
        loginService.requests.single.loginMode,
        NativeSocialLoginMode.talkPreferred,
      );
    }
  });

  test('emits safe structured diagnostics for a successful native login',
      () async {
    final entries = <String>[];
    final handler = NativeAuthBridgeHandler(
      loginService: FakeNativeSocialLoginService(
        result: const NativeSocialLoginResult(
          provider: 'google',
          accessToken: 'access-token-that-must-not-be-logged',
          idToken: 'id-token-that-must-not-be-logged',
        ),
      ),
      diagnostics: NativeAuthDiagnostics(write: entries.add),
      loadSessionRequest: RecordingSessionRequestLoader().load,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {'provider': 'google'},
      ),
      RecordingBridgeSender(),
    );

    expect(entries, <String>[
      'granite-native-auth provider=google stage=provider_login status=started',
      'granite-native-auth provider=google stage=provider_login status=completed',
      'granite-native-auth provider=google stage=session_sync status=started',
      'granite-native-auth provider=google stage=session_sync status=completed',
    ]);
    expect(
      entries.join('\n'),
      isNot(contains('access-token-that-must-not-be-logged')),
    );
    expect(
      entries.join('\n'),
      isNot(contains('id-token-that-must-not-be-logged')),
    );
  });

  test('emits an allowlisted provider status without exception text', () async {
    final entries = <String>[];
    final handler = NativeAuthBridgeHandler(
      loginService: ThrowingNativeSocialLoginService(
        error: const NativeSocialLoginException(
          'Apple returned a sensitive error message.',
          diagnosticCode: 'apple-native-login-failed',
          providerStatus: 405,
        ),
      ),
      diagnostics: NativeAuthDiagnostics(write: entries.add),
    );

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {'provider': 'apple'},
      ),
      RecordingBridgeSender(),
    );

    expect(entries, <String>[
      'granite-native-auth provider=apple stage=provider_login status=started',
      'granite-native-auth provider=apple stage=provider_login status=failed errorCode=apple-native-login-failed providerStatus=405',
    ]);
    expect(entries.join('\n'), isNot(contains('sensitive error message')));
  });

  test('ignores unsupported native auth providers', () async {
    final loginService = FakeNativeSocialLoginService(
      result: const NativeSocialLoginResult(
        provider: 'email',
        accessToken: 'token-1',
      ),
    );
    final loader = RecordingUrlLoader();
    final handler = NativeAuthBridgeHandler(
      loginService: loginService,
      loadUrl: loader.load,
      loadSessionRequest: RecordingSessionRequestLoader().load,
    );

    await handler.handle(
      const BridgeMessage(
        version: 1,
        id: 'native-login-1',
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'provider': 'email',
          'returnTo': '/me',
        },
      ),
      RecordingBridgeSender(),
    );

    expect(loginService.requests, isEmpty);
    expect(loader.urls, isEmpty);
  });

  test('notifies the WebView when native login fails', () async {
    final loader = RecordingUrlLoader();
    final sender = RecordingBridgeSender();
    final handler = NativeAuthBridgeHandler(
      loginService: ThrowingNativeSocialLoginService(),
      loadUrl: loader.load,
      loadSessionRequest: RecordingSessionRequestLoader().load,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

    await handler.handle(
      const BridgeMessage(
        version: 1,
        id: 'native-login-1',
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'provider': 'kakao',
          'returnTo': '/me',
        },
      ),
      sender,
    );

    expect(loader.urls, isEmpty);
    expect(sender.messages.single.type, 'auth.native.login.failed');
    expect(sender.messages.single.id, 'native-login-1');
    expect(sender.messages.single.payload['reason'], 'failed');
  });

  test('does nothing when the user cancels native login', () async {
    final loader = RecordingUrlLoader();
    final handler = NativeAuthBridgeHandler(
      loginService: CancelingNativeSocialLoginService(),
      loadUrl: loader.load,
      loadSessionRequest: RecordingSessionRequestLoader().load,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

    final sender = RecordingBridgeSender();
    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'provider': 'kakao',
          'returnTo': '/me',
        },
      ),
      sender,
    );

    expect(loader.urls, isEmpty);
    expect(sender.messages.single.type, 'auth.native.login.failed');
    expect(sender.messages.single.payload['reason'], 'cancelled');
  });

  test('only handles native login requests from web', () {
    const handler = NativeAuthBridgeHandler();

    expect(
      handler.canHandle(
        const BridgeMessage(
          version: 1,
          type: 'auth.native.login.requested',
          direction: BridgeDirection.webToNative,
        ),
      ),
      isTrue,
    );
    expect(
      handler.canHandle(
        const BridgeMessage(
          version: 1,
          type: 'auth.login.requested',
          direction: BridgeDirection.webToNative,
        ),
      ),
      isFalse,
    );
  });
}

class FakeNativeSocialLoginService implements NativeSocialLoginService {
  FakeNativeSocialLoginService({required this.result});

  final NativeSocialLoginResult result;
  final List<NativeSocialLoginRequest> requests = [];

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

class ThrowingNativeSocialLoginService implements NativeSocialLoginService {
  ThrowingNativeSocialLoginService({
    this.error = const NativeSocialLoginException('Native login failed.'),
  });

  final NativeSocialLoginException error;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    throw error;
  }
}

class CancelingNativeSocialLoginService implements NativeSocialLoginService {
  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    throw const NativeSocialLoginCanceledException();
  }
}

class RecordingUrlLoader {
  final List<Uri> urls = [];

  Future<void> load(Uri url) async {
    urls.add(url);
  }
}

class RecordingSessionRequestLoader {
  final List<NativeAuthSessionLoadRequest> requests = [];

  Future<void> load(NativeAuthSessionLoadRequest request) async {
    requests.add(request);
  }
}

class RecordingBridgeSender implements BridgeSender {
  final List<BridgeMessage> messages = [];

  @override
  Future<void> send(BridgeMessage message) async {
    messages.add(message);
  }
}
