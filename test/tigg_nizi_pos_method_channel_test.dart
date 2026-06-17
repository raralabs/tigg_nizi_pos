import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigg_nizi_pos/tigg_nizi_pos_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelTiggNiziPos platform = MethodChannelTiggNiziPos();
  const MethodChannel channel = MethodChannel('tigg_nizi_pos');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
