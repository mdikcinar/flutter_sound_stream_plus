part of flutter_sound_stream_plus;

class PlayerStream {
  static final PlayerStream _instance = PlayerStream._internal();
  factory PlayerStream() => _instance;

  final _playerStatusController = StreamController<SoundStreamStatus>.broadcast();
  final _audioStreamController = StreamController<Uint8List>();

  PlayerStream._internal() {
    FlutterSoundStreamPlusPlatform.instance.setMethodCallHandler(
      playerEventListener: _eventListener,
    );
    _playerStatusController.add(SoundStreamStatus.unset);
    _audioStreamController.stream.listen((data) {
      writeChunk(data);
    });
  }

  /// Initialize Player with specified [sampleRate]
  Future<dynamic> initialize({
    int sampleRate = 16000,
    bool showLogs = false,
    PlayerStreamAudioPort playerStreamAudioPort = PlayerStreamAudioPort.speaker,
  }) =>
      FlutterSoundStreamPlusPlatform.instance.initializePlayer(
        sampleRate: sampleRate,
        showLogs: showLogs,
        playerStreamAudioPort: playerStreamAudioPort,
      );

  /// Player will start receiving audio chunks (PCM 16bit data)
  /// to audio stream as Uint8List to play audio.
  Future<bool?> start() => FlutterSoundStreamPlusPlatform.instance.startPlayer();

  /// Player will stop receiving audio chunks.
  Future<bool?> stop() => FlutterSoundStreamPlusPlatform.instance.stopPlayer();

  /// Push audio [data] (PCM 16bit data) to player buffer as Uint8List
  /// to play audio. Chunks will be queued/scheduled to play sequentially
  Future<dynamic> writeChunk(Uint8List data) => FlutterSoundStreamPlusPlatform.instance.writeChunk(data);

  /// Current status of the [PlayerStream]
  Stream<SoundStreamStatus> get status => _playerStatusController.stream;

  /// Stream's sink to receive PCM 16bit data to send to Player
  StreamSink<Uint8List> get audioStream => _audioStreamController.sink;

  void _eventListener(dynamic event) {
    if (event == null) return;
    final String eventName = event["name"] ?? "";
    switch (eventName) {
      case "playerStatus":
        final String status = event["data"] ?? "Unset";
        _playerStatusController.add(SoundStreamStatus.values.firstWhere(
          (value) => value.name == status,
          orElse: () => SoundStreamStatus.unset,
        ));
        break;
    }
  }

  /// Stop and close all streams. This cannot be undone
  /// Only call this method if you don't want to use this anymore
  void dispose() {
    stop();
    _playerStatusController.close();
    _audioStreamController.close();
  }
}

enum PlayerStreamAudioPort {
  speaker,
  earpiece,
}
