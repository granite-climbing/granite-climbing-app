import 'package:google_sign_in/google_sign_in.dart' as google;

import '../../core/constants/app_constants.dart';
import 'native_social_login_service.dart';

class GoogleLoginTokens {
  const GoogleLoginTokens({
    this.accessToken,
    this.idToken,
  });

  final String? accessToken;
  final String? idToken;
}

abstract interface class GoogleLoginClient {
  Future<GoogleLoginTokens> login();
}

class GoogleNativeLoginService implements NativeSocialLoginService {
  const GoogleNativeLoginService({
    this.client = const SdkGoogleLoginClient(),
  });

  final GoogleLoginClient client;

  @override
  Future<NativeSocialLoginResult> login(
    NativeSocialLoginRequest request,
  ) async {
    if (request.provider != 'google') {
      throw NativeSocialLoginException(
        'Unsupported native login provider: ${request.provider}.',
      );
    }

    final GoogleLoginTokens tokens;
    try {
      tokens = await client.login();
    } on google.GoogleSignInException catch (error) {
      if (error.code == google.GoogleSignInExceptionCode.canceled) {
        throw const NativeSocialLoginCanceledException();
      }

      throw NativeSocialLoginException(
        'Google native login failed: ${error.description ?? error.code.name}.',
      );
    } catch (_) {
      throw const NativeSocialLoginException('Google native login failed.');
    }

    final accessToken = tokens.accessToken ?? '';
    final idToken = tokens.idToken;
    if (accessToken.isEmpty && (idToken == null || idToken.isEmpty)) {
      throw const NativeSocialLoginException(
        'Google native login returned no usable token.',
      );
    }

    return NativeSocialLoginResult(
      provider: 'google',
      accessToken: accessToken,
      idToken: idToken,
    );
  }
}

class SdkGoogleLoginClient implements GoogleLoginClient {
  const SdkGoogleLoginClient();

  static bool _initialized = false;

  @override
  Future<GoogleLoginTokens> login() async {
    if (!_initialized) {
      await google.GoogleSignIn.instance.initialize(
        clientId: _emptyToNull(AppConstants.googleClientId),
        serverClientId: _emptyToNull(AppConstants.googleServerClientId),
      );
      _initialized = true;
    }

    final account = await google.GoogleSignIn.instance.authenticate();
    return GoogleLoginTokens(
      idToken: account.authentication.idToken,
    );
  }

  String? _emptyToNull(String value) {
    return value.isEmpty ? null : value;
  }
}
