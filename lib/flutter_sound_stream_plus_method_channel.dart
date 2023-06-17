import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_sound_stream_plus_platform_interface.dart';

/// An implementation of [FlutterSoundStreamPlusPlatform] that uses method channels.
class MethodChannelFlutterSoundStreamPlus extends FlutterSoundStreamPlusPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_sound_stream_plus');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}