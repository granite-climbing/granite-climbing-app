import 'dart:convert';
import 'dart:typed_data';

import '../../core/constants/app_constants.dart';

class NativeAuthSessionRequest {
  const NativeAuthSessionRequest({
    required this.provider,
    required this.accessToken,
    this.idToken,
    this.returnTo,
  });

  final String provider;
  final String accessToken;
  final String? idToken;
  final String? returnTo;
}

class NativeBrowserSessionRequest {
  const NativeBrowserSessionRequest({
    required this.handoff,
    required this.verifier,
  });

  final String handoff;
  final String verifier;
}

class NativeAuthSessionLoadRequest {
  const NativeAuthSessionLoadRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
  });

  final Uri url;
  final String method;
  final Map<String, String> headers;
  final Uint8List body;

  String get bodyText => utf8.decode(body);
}

class NativeAuthSessionRequestBuilder {
  const NativeAuthSessionRequestBuilder({
    this.webBaseUrl,
  });

  final Uri? webBaseUrl;

  NativeAuthSessionLoadRequest build(NativeAuthSessionRequest request) {
    final form = <String, String>{
      'provider': request.provider,
      if (request.accessToken.isNotEmpty) 'accessToken': request.accessToken,
      if (request.idToken != null && request.idToken!.isNotEmpty)
        'idToken': request.idToken!,
      if (request.returnTo != null) 'returnTo': request.returnTo!,
    };

    return NativeAuthSessionLoadRequest(
      url: _webUrl('/api/auth/native/session'),
      method: 'POST',
      headers: const {
        'accept': 'text/html,application/xhtml+xml',
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: Uint8List.fromList(utf8.encode(Uri(queryParameters: form).query)),
    );
  }

  Uri get _resolvedWebBaseUrl {
    return webBaseUrl ?? Uri.parse(AppConstants.defaultWebUrl);
  }

  Uri _webUrl(String path) {
    return _resolvedWebBaseUrl.resolve(path);
  }
}

class NativeBrowserSessionRequestBuilder {
  const NativeBrowserSessionRequestBuilder({
    this.webBaseUrl,
  });

  final Uri? webBaseUrl;

  NativeAuthSessionLoadRequest build(NativeBrowserSessionRequest request) {
    final form = <String, String>{
      'handoff': request.handoff,
      'verifier': request.verifier,
    };

    return NativeAuthSessionLoadRequest(
      url: _webUrl('/api/auth/native/browser-session'),
      method: 'POST',
      headers: const {
        'accept': 'text/html,application/xhtml+xml',
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: Uint8List.fromList(utf8.encode(Uri(queryParameters: form).query)),
    );
  }

  Uri get _resolvedWebBaseUrl {
    return webBaseUrl ?? Uri.parse(AppConstants.defaultWebUrl);
  }

  Uri _webUrl(String path) {
    return _resolvedWebBaseUrl.resolve(path);
  }
}
