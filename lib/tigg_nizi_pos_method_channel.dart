import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tigg_nizi_pos_platform_interface.dart';

class MethodChannelTiggNiziPos extends TiggNiziPosPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('tigg_nizi_pos');

  final _connectionEventChannel = const EventChannel('tigg_nizi_pos/connection');

  @override
  Future<bool> connect() async {
    return await methodChannel.invokeMethod<bool>('connect') ?? false;
  }

  @override
  Future<void> disconnect() async {
    await methodChannel.invokeMethod<void>('disconnect');
  }

  @override
  Future<bool> isConnected() async {
    return await methodChannel.invokeMethod<bool>('isConnected') ?? false;
  }

  @override
  Future<void> sendCommand(String command) async {
    await methodChannel.invokeMethod<void>('sendCommand', {'command': command});
  }

  @override
  Stream<Map<String, dynamic>> get connectionStream {
    return _connectionEventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
  }
}
