
import 'flutter_sound_stream_plus_platform_interface.dart';

class FlutterSoundStreamPlus {
  Future<String?> getPlatformVersion() {
    return FlutterSoundStreamPlusPlatform.instance.getPlatformVersion();
  }
}
