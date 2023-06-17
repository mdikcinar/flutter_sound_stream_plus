//
//  HelperMethods.swift
//  flutter_sound_stream_plus
//
//  Created by Mustafa Ali Dikcinar on 17.06.2023.
//

import AVFoundation
import Foundation

class HelperMethods {
    private init() {}

    static func audioBufferToBytes(_ audioBuffer: AVAudioPCMBuffer) -> [UInt8] {
        let srcLeft = audioBuffer.int16ChannelData![0]
        let bytesPerFrame = audioBuffer.format.streamDescription.pointee.mBytesPerFrame
        let numBytes = Int(bytesPerFrame * audioBuffer.frameLength)

        // initialize bytes by 0
        var audioByteArray = [UInt8](repeating: 0, count: numBytes)

        srcLeft.withMemoryRebound(to: UInt8.self, capacity: numBytes) { srcByteData in
            audioByteArray.withUnsafeMutableBufferPointer {
                $0.baseAddress!.initialize(from: srcByteData, count: numBytes)
            }
        }

        return audioByteArray
    }

    static func bytesToAudioBuffer(buf: [UInt8], mPlayerInputFormat: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameLength = UInt32(buf.count) / mPlayerInputFormat.streamDescription.pointee.mBytesPerFrame

        let audioBuffer = AVAudioPCMBuffer(pcmFormat: mPlayerInputFormat, frameCapacity: frameLength)!
        audioBuffer.frameLength = frameLength

        let dstLeft = audioBuffer.int16ChannelData![0]

        buf.withUnsafeBufferPointer {
            let src = UnsafeRawPointer($0.baseAddress!).bindMemory(to: Int16.self, capacity: Int(frameLength))
            dstLeft.initialize(from: src, count: Int(frameLength))
        }

        return audioBuffer
    }

    static func 	(_ buffer: AVAudioPCMBuffer, from: AVAudioFormat, to: AVAudioFormat) -> AVAudioPCMBuffer {
        let formatConverter = AVAudioConverter(from: from, to: to)
        let ratio = Float(from.sampleRate) / Float(to.sampleRate)
        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: to, frameCapacity: UInt32(Float(buffer.frameCapacity) / ratio))!

        var error: NSError? = nil
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        formatConverter?.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)

        return pcmBuffer
    }
}
