import 'package:granite_climbing_app/data/bridge/bridge_handler.dart';
import 'package:granite_climbing_app/data/bridge/bridge_message.dart';

class IgnoredBridgeSender implements BridgeSender {
  const IgnoredBridgeSender();

  @override
  Future<void> send(BridgeMessage message) async {}
}
