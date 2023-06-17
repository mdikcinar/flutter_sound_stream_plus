library sound_stream;

import 'dart:async';
import 'dart:typed_data';

import 'flutter_sound_stream_plus_platform_interface.dart';

part 'recorder_stream.dart';
part 'player_stream.dart';

class SoundStream {
  static final SoundStream _instance = SoundStream._internal();
  factory SoundStream() => _instance;

  SoundStream._internal();

  /// Return [RecorderStream] instance (Singleton).
  RecorderStream get recorder => RecorderStream();

  /// Return [PlayerStream] instance (Singleton).
  PlayerStream get player => PlayerStream();
}

enum SoundStreamStatus {
  unset,
  initialized,
  playing,
  topped,
}
