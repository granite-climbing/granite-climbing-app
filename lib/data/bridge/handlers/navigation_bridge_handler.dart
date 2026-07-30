import 'dart:async';

import '../../../features/navigation/native_navigation_service.dart';
import '../bridge_handler.dart';
import '../bridge_message.dart';

class NavigationBridgeHandler implements BridgeHandler {
  static final _smartStoreUrl =
      Uri.parse('https://m.smartstore.naver.com/granite_kr');
  const NavigationBridgeHandler({
    this.navigationService = const DevNativeNavigationService(),
    this.allowedHosts = const <String>{
      'granite.kr',
      'www.granite.kr',
      'localhost',
      '127.0.0.1',
    },
  });

  final NativeNavigationService navigationService;
  final Set<String> allowedHosts;

  @override
  bool canHandle(BridgeMessage message) {
    return message.type == 'navigation.open.external.requested' &&
        message.direction == BridgeDirection.webToNative;
  }

  @override
  FutureOr<void> handle(BridgeMessage message, BridgeSender sender) async {
    final url = _readUri(message.payload['url']);
    if (url == null || !_isAllowedExternalUrl(url)) return;

    await navigationService.openExternal(url);
  }

  Uri? _readUri(Object? value) {
    if (value is! String) return null;
    return Uri.tryParse(value);
  }

  bool _isAllowedExternalUrl(Uri url) {
    if (url == _smartStoreUrl) return true;

    return (url.scheme == 'https' || url.scheme == 'http') &&
        allowedHosts.contains(url.host);
  }
}
