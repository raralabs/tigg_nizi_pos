import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'tigg_nizi_pos_method_channel.dart';

abstract class TiggNiziPosPlatform extends PlatformInterface {
  TiggNiziPosPlatform() : super(token: _token);

  static final Object _token = Object();
  static TiggNiziPosPlatform _instance = MethodChannelTiggNiziPos();

  static TiggNiziPosPlatform get instance => _instance;
  static set instance(TiggNiziPosPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> connect() {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<bool> isConnected() {
    throw UnimplementedError('isConnected() has not been implemented.');
  }

  Future<void> sendCommand(String command) {
    throw UnimplementedError('sendCommand() has not been implemented.');
  }

  Stream<Map<String, dynamic>> get connectionStream {
    throw UnimplementedError('connectionStream has not been implemented.');
  }

  /// Transfers [jpegBytes] to the device using the START_RTIMAGE protocol and
  /// displays it immediately.  The bytes must be JPEG baseline, 240 × 320 px,
  /// ≤ 30 KB.
  Future<void> displayRealTimeImage(Uint8List jpegBytes) {
    throw UnimplementedError(
        'displayRealTimeImage() has not been implemented.');
  }
}
