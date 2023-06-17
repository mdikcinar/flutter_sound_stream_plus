import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_sound_stream_plus_platform_interface.dart';

/// An implementation of [FlutterSoundStreamPlusPlatform] that uses method channels.
class MethodChannelFlutterSoundStreamPlus extends FlutterSoundStreamPlusPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_sound_stream_plus');

  @override
  void setMethodCallHandler({
    Function(dynamic event)? recorderEventListener,
    Function(dynamic event)? playerEventListener,
  }) {
    methodChannel.setMethodCallHandler(
      (call) {
        switch (call.method) {
          case "RecorderEvent":
            recorderEventListener?.call(call.arguments);
            break;
          case "PlayerEvent":
            playerEventListener?.call(call.arguments);
            break;
          case "PlatformEvent":
            recorderEventListener?.call(call.arguments);
            playerEventListener?.call(call.arguments);
            break;
        }
        return Future.value(null);
      },
    );
  }

  @override
  Future<void> initializePlayer({
    int sampleRate = 16000,
    bool showLogs = false,
  }) async {
    await methodChannel.invokeMethod("initializePlayer", {
      "sampleRate": sampleRate,
      "showLogs": showLogs,
    });
  }

  @override
  Future<bool?> startPlayer() => methodChannel.invokeMethod("startPlayer");

  @override
  Future<bool?> stopPlayer() => methodChannel.invokeMethod("stopPlayer");

  @override
  Future<dynamic> writeChunk(dynamic data) => methodChannel.invokeMethod("writeChunk", <String, dynamic>{"data": data});

  @override
  Future<void> initializeRecorder({
    int sampleRate = 16000,
    bool showLogs = false,
  }) async {
    await methodChannel.invokeMethod("initializeRecorder", {
      "sampleRate": sampleRate,
      "showLogs": showLogs,
    });
  }

  @override
  Future<bool?> startRecorder() => methodChannel.invokeMethod("startRecorder");

  @override
  Future<bool?> stopRecorder() => methodChannel.invokeMethod("stopRecorder");
}
