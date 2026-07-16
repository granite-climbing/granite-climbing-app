import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/native_auth_bridge_handler.dart';
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

  test('notifies the WebView when native login fails',
      () async {
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
  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    throw NativeSocialLoginException('Native login failed.');
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
