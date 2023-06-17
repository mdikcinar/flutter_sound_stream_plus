import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sound_stream_plus/flutter_sound_stream_plus.dart';
import 'package:flutter_sound_stream_plus/flutter_sound_stream_plus_platform_interface.dart';
import 'package:flutter_sound_stream_plus/flutter_sound_stream_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterSoundStreamPlusPlatform
    with MockPlatformInterfaceMixin
    implements FlutterSoundStreamPlusPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterSoundStreamPlusPlatform initialPlatform = FlutterSoundStreamPlusPlatform.instance;

  test('$MethodChannelFlutterSoundStreamPlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterSoundStreamPlus>());
  });

  test('getPlatformVersion', () async {
    FlutterSoundStreamPlus flutterSoundStreamPlusPlugin = FlutterSoundStreamPlus();
    MockFlutterSoundStreamPlusPlatform fakePlatform = MockFlutterSoundStreamPlusPlatform();
    FlutterSoundStreamPlusPlatform.instance = fakePlatform;

    expect(await flutterSoundStreamPlusPlugin.getPlatformVersion(), '42');
  });
}
