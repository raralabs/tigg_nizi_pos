import 'package:flutter_test/flutter_test.dart';
import 'package:tigg_nizi_pos/tigg_nizi_pos.dart';
import 'package:tigg_nizi_pos/tigg_nizi_pos_platform_interface.dart';
import 'package:tigg_nizi_pos/tigg_nizi_pos_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTiggNiziPosPlatform
    with MockPlatformInterfaceMixin
    implements TiggNiziPosPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TiggNiziPosPlatform initialPlatform = TiggNiziPosPlatform.instance;

  test('$MethodChannelTiggNiziPos is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTiggNiziPos>());
  });

  test('getPlatformVersion', () async {
    TiggNiziPos tiggNiziPosPlugin = TiggNiziPos();
    MockTiggNiziPosPlatform fakePlatform = MockTiggNiziPosPlatform();
    TiggNiziPosPlatform.instance = fakePlatform;

    expect(await tiggNiziPosPlugin.getPlatformVersion(), '42');
  });
}
