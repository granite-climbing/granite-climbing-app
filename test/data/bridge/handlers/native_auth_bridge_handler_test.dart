import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';
import 'package:granite_climbing_app/data/bridge/handlers/native_auth_bridge_handler.dart';
import 'package:granite_climbing_app/features/auth/native_auth_exchange_service.dart';
import 'package:granite_climbing_app/features/auth/native_social_login_service.dart';

void main() {
  test('native auth bridge exchanges token and loads consume URL', () async {
    final loginService = FakeNativeSocialLoginService(
      result: const NativeSocialLoginResult(
        provider: 'kakao',
        accessToken: 'token-1',
      ),
    );
    final exchangeService = FakeNativeAuthExchangeService(
      result: NativeAuthExchangeResult(
        consumeUrl: Uri.parse(
          'https://granite.kr/api/auth/native/consume?code=handoff-1',
        ),
      ),
    );
    final loader = RecordingUrlLoader();
    final handler = NativeAuthBridgeHandler(
      loginService: loginService,
      exchangeService: exchangeService,
      loadUrl: loader.load,
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
      RecordingBridgeSender(),
    );

    expect(loginService.requests.single.provider, 'kakao');
    expect(loginService.requests.single.returnTo, '/me');
    expect(exchangeService.requests.single.provider, 'kakao');
    expect(exchangeService.requests.single.accessToken, 'token-1');
    expect(loader.urls.single.toString(),
        'https://granite.kr/api/auth/native/consume?code=handoff-1');
  });

  test('ignores unsupported native auth providers', () async {
    final loginService = FakeNativeSocialLoginService(
      result: const NativeSocialLoginResult(
        provider: 'google',
        accessToken: 'token-1',
      ),
    );
    final loader = RecordingUrlLoader();
    final handler = NativeAuthBridgeHandler(
      loginService: loginService,
      exchangeService: FakeNativeAuthExchangeService(
        result: NativeAuthExchangeResult(
          consumeUrl: Uri.parse(
            'https://granite.kr/api/auth/native/consume?code=handoff-1',
          ),
        ),
      ),
      loadUrl: loader.load,
    );

    await handler.handle(
      const BridgeMessage(
        version: 1,
        type: 'auth.native.login.requested',
        direction: BridgeDirection.webToNative,
        payload: {
          'provider': 'google',
          'returnTo': '/me',
        },
      ),
      RecordingBridgeSender(),
    );

    expect(loginService.requests, isEmpty);
    expect(loader.urls, isEmpty);
  });

  test('loads login error URL when native login fails', () async {
    final loader = RecordingUrlLoader();
    final handler = NativeAuthBridgeHandler(
      loginService: ThrowingNativeSocialLoginService(),
      exchangeService: FakeNativeAuthExchangeService(
        result: NativeAuthExchangeResult(
          consumeUrl: Uri.parse(
            'https://granite.kr/api/auth/native/consume?code=handoff-1',
          ),
        ),
      ),
      loadUrl: loader.load,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

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
      RecordingBridgeSender(),
    );

    expect(
      loader.urls.single.toString(),
      'https://granite.kr/login?error=native_login_failed',
    );
  });

  test('does nothing when the user cancels native login', () async {
    final loader = RecordingUrlLoader();
    final handler = NativeAuthBridgeHandler(
      loginService: CancelingNativeSocialLoginService(),
      exchangeService: FakeNativeAuthExchangeService(
        result: NativeAuthExchangeResult(
          consumeUrl: Uri.parse(
            'https://granite.kr/api/auth/native/consume?code=handoff-1',
          ),
        ),
      ),
      loadUrl: loader.load,
      webBaseUrl: Uri.parse('https://granite.kr/app'),
    );

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
      RecordingBridgeSender(),
    );

    expect(loader.urls, isEmpty);
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

class FakeNativeAuthExchangeService implements NativeAuthExchangeGateway {
  FakeNativeAuthExchangeService({required this.result});

  final NativeAuthExchangeResult result;
  final List<NativeAuthExchangeRequest> requests = [];

  @override
  Future<NativeAuthExchangeResult> exchange(
    NativeAuthExchangeRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

class RecordingUrlLoader {
  final List<Uri> urls = [];

  Future<void> load(Uri url) async {
    urls.add(url);
  }
}

class RecordingBridgeSender implements BridgeSender {
  @override
  Future<void> send(BridgeMessage message) async {}
}
