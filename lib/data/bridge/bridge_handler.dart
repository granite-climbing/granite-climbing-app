import 'dart:async';

import 'bridge_message.dart';

abstract interface class BridgeHandler {
  bool canHandle(BridgeMessage message);

  FutureOr<void> handle(BridgeMessage message);
}
