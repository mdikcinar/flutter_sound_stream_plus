import AVFoundation
import Flutter
import UIKit

public enum SoundStreamErrors: String {
    case failedToRecord
    case failedToPlay
    case failedToStop
    case failedToWriteBuffer
    case unknown
}

public enum SoundStreamStatus: String {
    case unset
    case initialized
    case playing
    case stopped
}

public enum EventType: String {
    case recorderEvent
    case playerEvent
    case platformEvent
}

public class FlutterSoundStreamPlusPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel
    private var hasPermission: Bool = false
    private var debugLogging: Bool = false

    // MARK: Recorder's vars

    private let mAudioEngine = AVAudioEngine()
    private let mRecordBus = 0
    private var mInputNode: AVAudioInputNode
    private var mRecordSampleRate: Double = 16000 // 16Khz
    private var mRecordBufferSize: AVAudioFrameCount = 8192
    private var mRecordChannel = 0
    private var mRecordSettings: [String: Int]!
    private var mRecordFormat: AVAudioFormat!

    // MARK: Player's vars

    private let PLAYER_OUTPUT_SAMPLE_RATE: Double = 16000 // 16Khz
    private let mPlayerBus = 0
    private let mPlayerNode = AVAudioPlayerNode()
    private var mPlayerSampleRate: Double = 16000 // 16Khz
    private var mPlayerBufferSize: AVAudioFrameCount = 8192
    private var mPlayerOutputFormat: AVAudioFormat!
    private var mPlayerInputFormat: AVAudioFormat!

    // MARK: Init

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.mdikcinar.flutter_sound_stream_plus", binaryMessenger: registrar.messenger())
        let instance = FlutterSoundStreamPlusPlugin(channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
        self.mInputNode = mAudioEngine.inputNode

        super.init()
        attachPlayer()
        mAudioEngine.prepare()
    }

    private func attachPlayer() {
        mPlayerOutputFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: PLAYER_OUTPUT_SAMPLE_RATE, channels: 1, interleaved: true)

        mAudioEngine.attach(mPlayerNode)
        mAudioEngine.connect(mPlayerNode, to: mAudioEngine.outputNode, format: mPlayerOutputFormat)
    }

    // MARK: Handle Method Calls And Invoke Methods

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasPermission":
            hasPermission(result)
        case "initializeRecorder":
            initializeRecorder(call, result)
        case "startRecording":
            startRecording(result)
        case "stopRecording":
            stopRecording(result)
        case "initializePlayer":
            initializePlayer(call, result)
        case "startPlayer":
            startPlayer(result)
        case "stopPlayer":
            stopPlayer(result)
        case "writeChunk":
            writeChunk(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func invokeFlutter(_ method: String, _ arguments: Any?) {
        channel.invokeMethod(method, arguments: arguments)
    }

    private func sendEventMethod(name: String, data: Any, eventType: EventType = .platformEvent) {
        var eventData: [String: Any] = [:]
        eventData["name"] = name
        eventData["data"] = data
        invokeFlutter(eventType.rawValue, eventData)
    }

    // MARK: Plugin methods

    private func debugPrint(_ log: String) {
        if debugLogging {
            sendEventMethod(name: "debugPrint", data: log)
        }
    }

    private func startEngine() {
        guard !mAudioEngine.isRunning else {
            return
        }

        try? mAudioEngine.start()
    }

    private func stopEngine() {
        mAudioEngine.stop()
        mAudioEngine.reset()
    }

    private func hasPermission(_ result: @escaping FlutterResult) {
        checkAndRequestPermission { value in
            result(value)
        }
    }

    private func checkAndRequestPermission(completion callback: @escaping ((Bool) -> Void)) {
        if hasPermission {
            callback(hasPermission)
            return
        }

        var permission: AVAudioSession.RecordPermission
        #if swift(>=4.2)
        permission = AVAudioSession.sharedInstance().recordPermission
        #else
        permission = AVAudioSession.sharedInstance().recordPermission()
        #endif
        switch permission {
        case .granted:
            debugPrint("granted")
            hasPermission = true
            callback(hasPermission)
        case .denied:
            debugPrint("denied")
            hasPermission = false
            callback(hasPermission)
        case .undetermined:
            debugPrint("undetermined")
            AVAudioSession.sharedInstance().requestRecordPermission { [unowned self] allowed in
                if allowed {
                    self.hasPermission = true
                    debugPrint("undetermined true")
                    callback(self.hasPermission)
                } else {
                    self.hasPermission = false
                    debugPrint("undetermined false")
                    callback(self.hasPermission)
                }
            }
        default:
            callback(hasPermission)
        }
    }

    private func sendPlayerStatus(_ status: SoundStreamStatus) {
        sendEventMethod(name: "playerStatus", data: status.rawValue, eventType: .playerEvent)
    }

    // MARK: Recorder methods

    private func sendRecorderStatus(_ status: SoundStreamStatus) {
        sendEventMethod(name: "recorderStatus", data: status.rawValue, eventType: .recorderEvent)
    }

    private func initializeRecorder(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let argsArr = call.arguments as? [String: AnyObject]
        else {
            result(FlutterError(code: SoundStreamErrors.unknown.rawValue,
                                message: "Incorrect parameters",
                                details: nil))
            return
        }
        mRecordSampleRate = argsArr["sampleRate"] as? Double ?? mRecordSampleRate
        debugLogging = argsArr["showLogs"] as? Bool ?? debugLogging
        let audioPort = argsArr["audioPort"] as? String ?? "speaker"
        do {
            if audioPort == "speaker" {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.overrideOutputAudioPort(.speaker)
            }

        } catch {
            debugPrint("error overriding OutputAudioPort")
        }
        mRecordFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: mRecordSampleRate, channels: 1, interleaved: true)

        checkAndRequestPermission { isGranted in
            if isGranted {
                self.sendRecorderStatus(SoundStreamStatus.initialized)
                result(true)
            } else {
                result(FlutterError(code: SoundStreamErrors.unknown.rawValue,
                                    message: "Incorrect parameters",
                                    details: nil))
            }
        }
    }

    private func startRecording(_ result: @escaping FlutterResult) {
        resetEngineForRecord()
        startEngine()
        sendRecorderStatus(SoundStreamStatus.playing)
        result(true)
    }

    private func stopRecording(_ result: @escaping FlutterResult) {
        mAudioEngine.inputNode.removeTap(onBus: mRecordBus)
        sendRecorderStatus(SoundStreamStatus.stopped)
        result(true)
    }

    private func resetEngineForRecord() {
        mAudioEngine.inputNode.removeTap(onBus: mRecordBus)
        let input = mAudioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: mRecordBus)
        let converter = AVAudioConverter(from: inputFormat, to: mRecordFormat!)!
        let ratio = Float(inputFormat.sampleRate) / Float(mRecordFormat.sampleRate)

        input.installTap(onBus: mRecordBus, bufferSize: mRecordBufferSize, format: inputFormat) { buffer, _ in
            let inputCallback: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.mRecordFormat!, frameCapacity: UInt32(Float(buffer.frameCapacity) / ratio))!

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
            assert(status != .error)

            if self.mRecordFormat?.commonFormat == AVAudioCommonFormat.pcmFormatInt16 {
                let values = HelperMethods.audioBufferToBytes(convertedBuffer)
                self.sendMicData(values)
            }
        }
    }

    private func sendMicData(_ data: [UInt8]) {
        let channelData = FlutterStandardTypedData(bytes: NSData(bytes: data, length: data.count) as Data)
        sendEventMethod(name: "dataPeriod", data: channelData, eventType: .recorderEvent)
    }

    // MARK: Player methods

    private func initializePlayer(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let argsArr = call.arguments as? [String: AnyObject]
        else {
            result(FlutterError(code: SoundStreamErrors.unknown.rawValue,
                                message: "Incorrect parameters",
                                details: nil))
            return
        }
        mPlayerSampleRate = argsArr["sampleRate"] as? Double ?? mPlayerSampleRate
        debugLogging = argsArr["showLogs"] as? Bool ?? debugLogging
        mPlayerInputFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: mPlayerSampleRate, channels: 1, interleaved: true)
        sendPlayerStatus(SoundStreamStatus.initialized)
    }

    private func startPlayer(_ result: @escaping FlutterResult) {
        startEngine()
        if !mPlayerNode.isPlaying {
            mPlayerNode.play()
        }
        sendPlayerStatus(SoundStreamStatus.playing)
        result(true)
    }

    private func stopPlayer(_ result: @escaping FlutterResult) {
        if mPlayerNode.isPlaying {
            mPlayerNode.stop()
        }
        sendPlayerStatus(SoundStreamStatus.stopped)
        result(true)
    }

    private func writeChunk(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let argsArr = call.arguments as? [String: AnyObject],
              let data = argsArr["data"] as? FlutterStandardTypedData
        else {
            result(FlutterError(code: SoundStreamErrors.failedToWriteBuffer.rawValue,
                                message: "Failed to write Player buffer",
                                details: nil))
            return
        }
        let byteData = [UInt8](data.data)
        pushPlayerChunk(byteData, result)
    }

    private func pushPlayerChunk(_ chunk: [UInt8], _ result: @escaping FlutterResult) {
        let buffer = HelperMethods.bytesToAudioBuffer(buf: chunk, mPlayerInputFormat: mPlayerInputFormat)
        mPlayerNode.scheduleBuffer(HelperMethods.convertBufferFormat(
            buffer,
            from: mPlayerInputFormat,
            to: mPlayerOutputFormat
        ))
        result(true)
    }
}
