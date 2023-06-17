/* import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sound_stream_plus/sound_stream.dart';
import 'package:flutter_sound_stream_plus/flutter_sound_stream_plus_platform_interface.dart';
import 'package:flutter_sound_stream_plus/flutter_sound_stream_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterSoundStreamPlusPlatform with MockPlatformInterfaceMixin implements FlutterSoundStreamPlusPlatform {
  @override
  Future<void> initializePlayer({int sampleRate = 16000, bool showLogs = false}) {
    // TODO: implement initializePlayer
    throw UnimplementedError();
  }

  @override
  Future<void> initializeRecorder({int sampleRate = 16000, bool showLogs = false}) {
    // TODO: implement initializeRecorder
    throw UnimplementedError();
  }

  @override
  void setMethodCallHandler(
      {Function(dynamic event)? recorderEventListener, Function(dynamic event)? playerEventListener}) {
    // TODO: implement setMethodCallHandler
  }

  @override
  Future<bool?> startPlayer() {
    // TODO: implement startPlayer
    throw UnimplementedError();
  }

  @override
  Future<bool?> startRecording() {
    // TODO: implement startRecorder
    throw UnimplementedError();
  }

  @override
  Future<bool?> stopRecording() {
    // TODO: implement stopPlayer
    throw UnimplementedError();
  }

  @override
  Future writeChunk(data) {
    // TODO: implement writeChunk
    throw UnimplementedError();
  }

  @override
  Future<bool?> stopPlayer() {
    // TODO: implement stopPlayer
    throw UnimplementedError();
  }
}

void main() {
  final FlutterSoundStreamPlusPlatform initialPlatform = FlutterSoundStreamPlusPlatform.instance;

  test('$MethodChannelFlutterSoundStreamPlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterSoundStreamPlus>());
  });

  test('getPlatformVersion', () async {
    SoundStream flutterSoundStreamPlusPlugin = SoundStream();
    MockFlutterSoundStreamPlusPlatform fakePlatform = MockFlutterSoundStreamPlusPlatform();
    FlutterSoundStreamPlusPlatform.instance = fakePlatform;

    //expect(await flutterSoundStreamPlusPlugin.getPlatformVersion(), '42');
  });
}
 */