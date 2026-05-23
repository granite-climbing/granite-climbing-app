import 'dart:async';

import '../../../features/share/native_share_service.dart';
import '../bridge_handler.dart';
import '../bridge_message.dart';

class ShareBridgeHandler implements BridgeHandler {
  const ShareBridgeHandler({
    this.shareService = const DevNativeShareService(),
  });

  final NativeShareService shareService;

  @override
  bool canHandle(BridgeMessage message) {
    return message.type == 'share.route.requested' &&
        message.direction == BridgeDirection.webToNative;
  }

  @override
  FutureOr<void> handle(BridgeMessage message, BridgeSender sender) async {
    final request = _readRouteRequest(message.payload);
    if (request == null) {
      await _sendFailed(
        sender,
        message.id,
        code: 'invalid_payload',
        errorMessage: 'Route share payload is invalid.',
      );
      return;
    }

    final result = await shareService.shareRoute(request);
    if (result.ok) {
      await sender.send(
        BridgeMessage(
          version: 1,
          id: message.id,
          type: 'share.route.completed',
          direction: BridgeDirection.nativeToWeb,
          payload: const <String, Object?>{
            'ok': true,
          },
        ),
      );
      return;
    }

    await _sendFailed(
      sender,
      message.id,
      code: result.errorCode ?? 'operation_failed',
      errorMessage: result.errorMessage ?? 'Native share failed.',
    );
  }

  NativeShareRouteRequest? _readRouteRequest(Map<String, Object?> payload) {
    final routeId = payload['routeId'];
    final title = payload['title'];
    final url = payload['url'];
    final parsedUrl = url is String ? Uri.tryParse(url) : null;

    if (routeId is! String ||
        routeId.isEmpty ||
        title is! String ||
        title.isEmpty ||
        parsedUrl == null ||
        !parsedUrl.hasScheme) {
      return null;
    }

    return NativeShareRouteRequest(
      routeId: routeId,
      title: title,
      url: parsedUrl,
    );
  }

  Future<void> _sendFailed(
    BridgeSender sender,
    String? id, {
    required String code,
    required String errorMessage,
  }) {
    return sender.send(
      BridgeMessage(
        version: 1,
        id: id,
        type: 'share.route.failed',
        direction: BridgeDirection.nativeToWeb,
        payload: <String, Object?>{
          'ok': false,
          'error': <String, Object?>{
            'code': code,
            'message': errorMessage,
          },
        },
      ),
    );
  }
}
