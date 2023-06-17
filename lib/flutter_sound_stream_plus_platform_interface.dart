import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_sound_stream_plus_method_channel.dart';

abstract class FlutterSoundStreamPlusPlatform extends PlatformInterface {
  /// Constructs a FlutterSoundStreamPlusPlatform.
  FlutterSoundStreamPlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterSoundStreamPlusPlatform _instance = MethodChannelFlutterSoundStreamPlus();

  /// The default instance of [FlutterSoundStreamPlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterSoundStreamPlus].
  static FlutterSoundStreamPlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterSoundStreamPlusPlatform] when
  /// they register themselves.
  static set instance(FlutterSoundStreamPlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  void setMethodCallHandler({
    Function(dynamic event)? recorderEventListener,
    Function(dynamic event)? playerEventListener,
  });

  Future<void> initializePlayer({
    int sampleRate = 16000,
    bool showLogs = false,
  });

  Future<bool?> startPlayer();

  Future<bool?> stopPlayer();

  Future<dynamic> writeChunk(dynamic data);

  Future<void> initializeRecorder({
    int sampleRate = 16000,
    bool showLogs = false,
  });

  Future<bool?> startRecorder();

  Future<bool?> stopRecorder();
}
