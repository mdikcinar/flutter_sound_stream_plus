package com.mdikcinar.flutter_sound_stream_plus

import android.content.Context
import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.*
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.ShortBuffer

enum class SoundStreamErrors {
  failedToRecord,
  failedToPlay,
  failedToStop,
  failedToWriteBuffer,
  unknown,
}

enum class SoundStreamStatus {
  unset,
  initialized,
  playing,
  stopped,
}

enum class EventType {
   recorderEvent,
   playerEvent,
   platformEvent,
}


/** FlutterSoundStreamPlusPlugin */
class FlutterSoundStreamPlusPlugin: FlutterPlugin, MethodCallHandler, PluginRegistry.RequestPermissionsResultListener,
      ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity

  private lateinit var channel : MethodChannel
  private val logTag = "SoundStreamPlusPlugin"
  private val audioRecordPermissionCode = 14887
  private var currentActivity: Activity? = null
  private var permissionToRecordAudio: Boolean = false
  private var pluginContext: Context? = null
  private var debugLogging: Boolean = false
  private var activeResult: Result? = null


  //========= Recorder's vars
  private val mRecordFormat = AudioFormat.ENCODING_PCM_16BIT
  private var mRecordSampleRate = 16000 // 16Khz
  private var mRecorderBufferSize = 8192
  private var mPeriodFrames = 8192
  private var audioData: ShortArray? = null
  private var mRecorder: AudioRecord? = null
  private var mListener: AudioRecord.OnRecordPositionUpdateListener? = null

  //========= Player's vars
  private var mAudioTrack: AudioTrack? = null
  private var mPlayerSampleRate = 16000 // 16Khz
  private var mPlayerBufferSize = 10240
  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  private var mPlayerFormat: AudioFormat = AudioFormat.Builder()
          .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
          .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
          .setSampleRate(mPlayerSampleRate)
          .build()


  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.mdikcinar.flutter_sound_stream_plus")
    channel.setMethodCallHandler(this)
  }

  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    try {
        when (call.method) {
        "hasPermission" -> hasPermission(result)
        "initializeRecorder" -> initializeRecorder(call, result)
        "startRecording" -> startRecording(result)
        "stopRecording" -> stopRecording(result)
        "initializePlayer" -> initializePlayer(call, result)
        "startPlayer" -> startPlayer(result)
        "stopPlayer" -> stopPlayer(result)
        "writeChunk" -> writeChunk(call, result)
        else -> result.notImplemented()
      }
    }
    catch(e: Exception) {
      Log.e(logTag, "Unexpected exception", e)
      result.error(SoundStreamErrors.unknown.name,
                    "Unexpected exception", e.localizedMessage)    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    mListener?.onMarkerReached(null)
    mListener?.onPeriodicNotification(null)
    mListener = null
    mRecorder?.stop()
    mRecorder?.release()
    mRecorder = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
      currentActivity = binding.activity
      binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {

  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
      currentActivity = binding.activity
      binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
  }


  private fun debugLog(msg: String) {
    if (debugLogging) {
      Log.d(logTag, msg)
      channel.invokeMethod("debugPrint", msg)
    }
  }

  /** ======== Plugin methods ======== **/

  private fun hasRecordPermission(): Boolean {
    if (permissionToRecordAudio) return true

    val localContext = pluginContext
    permissionToRecordAudio = localContext != null && ContextCompat.checkSelfPermission(localContext,
            Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    return permissionToRecordAudio

  }

  private fun hasPermission(result: Result) {
    result.success(hasRecordPermission())
  }

  private fun requestRecordPermission() {
    val localActivity = currentActivity
    if (!hasRecordPermission() && localActivity != null) {
      debugLog("requesting RECORD_AUDIO permission")
      ActivityCompat.requestPermissions(localActivity,
              arrayOf(Manifest.permission.RECORD_AUDIO), audioRecordPermissionCode)
    }
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
    when (requestCode) {
      audioRecordPermissionCode -> {
        if (grantResults != null) {
          permissionToRecordAudio = grantResults.isNotEmpty() &&
                  grantResults[0] == PackageManager.PERMISSION_GRANTED
        }
        completeInitializeRecorder()
        return true
      }
    }
    return false
  }

  private fun initializeRecorder(@NonNull call: MethodCall, @NonNull result: Result) {
    mRecordSampleRate = call.argument<Int>("sampleRate") ?: mRecordSampleRate
    debugLogging = call.argument<Boolean>("showLogs") ?: false
    mPeriodFrames = AudioRecord.getMinBufferSize(mRecordSampleRate, AudioFormat.CHANNEL_IN_MONO, mRecordFormat)
    mRecorderBufferSize = mPeriodFrames * 2
    audioData = ShortArray(mPeriodFrames)
    activeResult = result

    val localContext = pluginContext
    if (null == localContext) {
      completeInitializeRecorder()
      return
    }
    permissionToRecordAudio = ContextCompat.checkSelfPermission(localContext,
            Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    if (!permissionToRecordAudio) {
      requestRecordPermission()
    } else {
      debugLog("has permission, completing")
      completeInitializeRecorder()
    }
    debugLog("leaving initializeIfPermitted")
  }

  private fun initRecorder() {
    if (mRecorder?.state == AudioRecord.STATE_INITIALIZED) {
      return
    }
    mRecorder = AudioRecord(MediaRecorder.AudioSource.MIC, mRecordSampleRate, AudioFormat.CHANNEL_IN_MONO, mRecordFormat, mRecorderBufferSize)
    if (mRecorder != null) {
      mListener = createRecordListener()
      mRecorder?.positionNotificationPeriod = mPeriodFrames
      mRecorder?.setRecordPositionUpdateListener(mListener)
    }
  }

  private fun completeInitializeRecorder() {

    debugLog("completeInitialize")
    val initResult: HashMap<String, Any> = HashMap()

    if (permissionToRecordAudio) {
      mRecorder?.release()
      initRecorder()
      initResult["isMeteringEnabled"] = true
      sendRecorderStatus(SoundStreamStatus.initialized)
    }

    initResult["success"] = permissionToRecordAudio
    debugLog("sending result")
    activeResult?.success(initResult)
    debugLog("leaving complete")
    activeResult = null
  }

  private fun sendEventMethod(name: String, data: Any, eventType: EventType = EventType.platformEvent) {
    val eventData: HashMap<String, Any> = HashMap()
    eventData["name"] = name
    eventData["data"] = data
    channel.invokeMethod(eventType.name, eventData)
  }

  private fun startRecording(result: Result) {
    try {
      if (mRecorder?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
        result.success(true)
        return
      }
      initRecorder()
      mRecorder!!.startRecording()
      sendRecorderStatus(SoundStreamStatus.playing)
      result.success(true)
    } catch (e: IllegalStateException) {
      debugLog("record() failed")
      result.error(SoundStreamErrors.failedToRecord.name, "Failed to start recording", e.localizedMessage)
      throw e
    }
  }

  private fun stopRecording(result: Result) {
    try {
      if (mRecorder!!.recordingState == AudioRecord.RECORDSTATE_STOPPED) {
        result.success(true)
        return
      }
      mRecorder!!.stop()
      sendRecorderStatus(SoundStreamStatus.stopped)
      result.success(true)
    } catch (e: IllegalStateException) {
      debugLog("record() failed")
      result.error(SoundStreamErrors.failedToRecord.name, "Failed to start recording", e.localizedMessage)
      throw e
    }
  }

  private fun sendRecorderStatus(status: SoundStreamStatus) {
    sendEventMethod("recorderStatus", status.name, EventType.recorderEvent)
  }

  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  private fun initializePlayer(@NonNull call: MethodCall, @NonNull result: Result) {
    mPlayerSampleRate = call.argument<Int>("sampleRate") ?: mPlayerSampleRate
    debugLogging = call.argument<Boolean>("showLogs") ?: false
    mPlayerFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .setSampleRate(mPlayerSampleRate)
            .build()

    mPlayerBufferSize = AudioTrack.getMinBufferSize(mPlayerSampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)

    if (mAudioTrack?.state == AudioTrack.STATE_INITIALIZED) {
      mAudioTrack?.release()
    }

    val audioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
            .build()
    mAudioTrack = AudioTrack(audioAttributes, mPlayerFormat, mPlayerBufferSize, AudioTrack.MODE_STREAM, AudioManager.AUDIO_SESSION_ID_GENERATE)
    result.success(true)
    sendPlayerStatus(SoundStreamStatus.initialized)
  }

  private fun writeChunk(@NonNull call: MethodCall, @NonNull result: Result) {
    val data = call.argument<ByteArray>("data")
    if (data != null) {
      pushPlayerChunk(data, result)
    } else {
      result.error(SoundStreamErrors.failedToWriteBuffer.name, "Failed to write Player buffer", "'data' is null")
    }
  }

  private fun pushPlayerChunk(chunk: ByteArray, result: Result) {
    try {
      val buffer = ByteBuffer.wrap(chunk)
      val shortBuffer = ShortBuffer.allocate(chunk.size / 2)
      shortBuffer.put(buffer.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer())
      val shortChunk = shortBuffer.array()

      mAudioTrack?.write(shortChunk, 0, shortChunk.size)
      result.success(true)
    } catch (e: Exception) {
      result.error(SoundStreamErrors.failedToWriteBuffer.name, "Failed to write Player buffer", e.localizedMessage)
      throw e
    }
  }

  private fun startPlayer(result: Result) {
    try {
      if (mAudioTrack?.state == AudioTrack.PLAYSTATE_PLAYING) {
        result.success(true)
        return
      }

      mAudioTrack!!.play()
      sendPlayerStatus(SoundStreamStatus.playing)
      result.success(true)
    } catch (e: Exception) {
      result.error(SoundStreamErrors.failedToPlay.name, "Failed to start Player", e.localizedMessage)
      throw e
    }
  }

  private fun stopPlayer(result: Result) {
    try {
      if (mAudioTrack?.state == AudioTrack.STATE_INITIALIZED) {
        mAudioTrack?.stop()
      }
      sendPlayerStatus(SoundStreamStatus.stopped)
      result.success(true)
    } catch (e: Exception) {
      result.error(SoundStreamErrors.failedToStop.name, "Failed to stop Player", e.localizedMessage)
      throw e
    }
  }

  private fun sendPlayerStatus(status: SoundStreamStatus) {
    sendEventMethod("playerStatus", status.name, EventType.playerEvent)
  }

  private fun createRecordListener(): AudioRecord.OnRecordPositionUpdateListener? {
    return object : AudioRecord.OnRecordPositionUpdateListener {
      override fun onMarkerReached(recorder: AudioRecord) {
        recorder.read(audioData!!, 0, mRecorderBufferSize)
      }

      override fun onPeriodicNotification(recorder: AudioRecord) {
        val data = audioData!!
        val shortOut = recorder.read(data, 0, mPeriodFrames)
        // this condistion to prevent app crash from happening in Android Devices
        // See issues: https://github.com/CasperPas/flutter-sound-stream/issues/25
        if (shortOut < 1) { return }
        // https://flutter.io/platform-channels/#codec
        // convert short to int because of platform-channel's limitation
        val byteBuffer = ByteBuffer.allocate(shortOut * 2)
        byteBuffer.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().put(data)

        sendEventMethod("dataPeriod", byteBuffer.array(), EventType.recorderEvent)
      }
    }

  }

}
