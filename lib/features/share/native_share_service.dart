import 'package:share_plus/share_plus.dart';

class NativeShareRouteRequest {
  const NativeShareRouteRequest({
    required this.routeId,
    required this.title,
    required this.url,
  });

  final String routeId;
  final String title;
  final Uri url;
}

class NativeShareResult {
  const NativeShareResult._({
    required this.ok,
    this.errorCode,
    this.errorMessage,
  });

  factory NativeShareResult.completed() {
    return const NativeShareResult._(ok: true);
  }

  factory NativeShareResult.failed({
    required String code,
    required String message,
  }) {
    return NativeShareResult._(
      ok: false,
      errorCode: code,
      errorMessage: message,
    );
  }

  final bool ok;
  final String? errorCode;
  final String? errorMessage;
}

abstract interface class NativeShareService {
  Future<NativeShareResult> shareRoute(NativeShareRouteRequest request);
}

class DevNativeShareService implements NativeShareService {
  const DevNativeShareService();

  @override
  Future<NativeShareResult> shareRoute(NativeShareRouteRequest request) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: request.title,
          uri: request.url,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return NativeShareResult.failed(
          code: 'operation_cancelled',
          message: 'Native share was dismissed.',
        );
      }

      return NativeShareResult.completed();
    } catch (_) {
      return NativeShareResult.failed(
        code: 'native_share_unavailable',
        message: 'Native share is unavailable on this device.',
      );
    }
  }
}
