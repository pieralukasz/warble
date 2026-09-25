import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

let transcriptionFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 16_000,
    channels: 1,
    interleaved: false
)!

let transcriptionFileSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM,
    AVSampleRateKey: 16_000,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false,
]

final class MonoAudioFileSink {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?
    private let onLevel: ((Float) -> Void)?

    init(url: URL, onLevel: ((Float) -> Void)? = nil) throws {
        self.onLevel = onLevel
        file = try AVAudioFile(
            forWriting: url,
            settings: transcriptionFileSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        if let onLevel {
            onLevel(AudioLevel.normalizedLevel(of: buffer))
        }
        lock.lock()
        defer { lock.unlock() }
        guard let file else { return }

        if buffer.format == transcriptionFormat {
            try? file.write(from: buffer)
            return
        }

        if converter == nil || converterInputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: transcriptionFormat)
            converterInputFormat = buffer.format
        }
        guard let converter else { return }

        let ratio = transcriptionFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 32
        guard let converted = AVAudioPCMBuffer(
            pcmFormat: transcriptionFormat,
            frameCapacity: capacity
        ) else { return }

        var suppliedInput = false
        var conversionError: NSError?
        converter.convert(to: converted, error: &conversionError) { _, status in
            if suppliedInput {
                status.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            status.pointee = .haveData
            return buffer
        }

        if conversionError == nil && converted.frameLength > 0 {
            try? file.write(from: converted)
        }
    }

    func close() {
        lock.lock()
        file = nil
        converter = nil
        converterInputFormat = nil
        lock.unlock()
    }
}

final class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    let sink: MonoAudioFileSink

    init(sink: MonoAudioFileSink) {
        self.sink = sink
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio, sampleBuffer.isValid else { return }

        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            guard let description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                  let format = AVAudioFormat(
                    standardFormatWithSampleRate: description.mSampleRate,
                    channels: description.mChannelsPerFrame
                  ),
                  let pcmBuffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: audioBufferList.unsafePointer
                  ) else { return }
            sink.append(pcmBuffer)
        }
    }
}
