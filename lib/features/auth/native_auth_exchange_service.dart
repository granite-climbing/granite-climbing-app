import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';

class NativeAuthExchangeRequest {
  const NativeAuthExchangeRequest({
    required this.provider,
    required this.accessToken,
    this.returnTo,
  });

  final String provider;
  final String accessToken;
  final String? returnTo;
}

class NativeAuthExchangeResult {
  const NativeAuthExchangeResult({
    required this.consumeUrl,
  });

  final Uri consumeUrl;
}

abstract interface class NativeAuthExchangeGateway {
  Future<NativeAuthExchangeResult> exchange(NativeAuthExchangeRequest request);
}

class NativeAuthExchangeException implements Exception {
  const NativeAuthExchangeException(this.message);

  final String message;

  @override
  String toString() {
    return 'NativeAuthExchangeException: $message';
  }
}

class NativeAuthExchangeService implements NativeAuthExchangeGateway {
  NativeAuthExchangeService({
    http.Client? client,
    Uri? webBaseUrl,
  })  : _client = client ?? http.Client(),
        _webBaseUrl = webBaseUrl ?? Uri.parse(AppConstants.defaultWebUrl);

  final http.Client _client;
  final Uri _webBaseUrl;

  @override
  Future<NativeAuthExchangeResult> exchange(
    NativeAuthExchangeRequest request,
  ) async {
    final response = await _client.post(
      _webUrl('/api/auth/native/exchange'),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode(
        <String, Object?>{
          'provider': request.provider,
          'accessToken': request.accessToken,
          if (request.returnTo != null) 'returnTo': request.returnTo,
        },
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NativeAuthExchangeException(
        'Native auth exchange failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const NativeAuthExchangeException(
        'Native auth exchange response is invalid.',
      );
    }

    final handoffCode = decoded['handoffCode'];
    if (handoffCode is! String || handoffCode.isEmpty) {
      throw const NativeAuthExchangeException(
        'Native auth exchange response is missing handoffCode.',
      );
    }

    return NativeAuthExchangeResult(
      consumeUrl: _webUrl('/api/auth/native/consume').replace(
        queryParameters: <String, String>{
          'code': handoffCode,
        },
      ),
    );
  }

  Uri _webUrl(String path) {
    return _webBaseUrl.replace(
      path: path,
      query: null,
      fragment: null,
    );
  }
}
