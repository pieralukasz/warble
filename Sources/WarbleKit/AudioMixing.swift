import AVFoundation

extension AudioRecorder {
    /// Averages the microphone and system tracks into one mono transcription file.
    static func mixAudioFiles(
        microphoneURL: URL,
        systemAudioURL: URL,
        outputURL: URL
    ) throws {
        let microphoneFile = try AVAudioFile(
            forReading: microphoneURL,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let systemFile = try AVAudioFile(
            forReading: systemAudioURL,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: transcriptionFileSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        let chunkSize: AVAudioFrameCount = 4096
        let microphoneBuffer = AVAudioPCMBuffer(
            pcmFormat: transcriptionFormat,
            frameCapacity: chunkSize
        )!
        let systemBuffer = AVAudioPCMBuffer(
            pcmFormat: transcriptionFormat,
            frameCapacity: chunkSize
        )!
        let mixedBuffer = AVAudioPCMBuffer(
            pcmFormat: transcriptionFormat,
            frameCapacity: chunkSize
        )!

        while microphoneFile.framePosition < microphoneFile.length
            || systemFile.framePosition < systemFile.length {
            microphoneBuffer.frameLength = 0
            systemBuffer.frameLength = 0
            if microphoneFile.framePosition < microphoneFile.length {
                try microphoneFile.read(into: microphoneBuffer, frameCount: chunkSize)
            }
            if systemFile.framePosition < systemFile.length {
                try systemFile.read(into: systemBuffer, frameCount: chunkSize)
            }

            let frameCount = max(microphoneBuffer.frameLength, systemBuffer.frameLength)
            guard frameCount > 0,
                  let microphoneSamples = microphoneBuffer.floatChannelData?[0],
                  let systemSamples = systemBuffer.floatChannelData?[0],
                  let mixedSamples = mixedBuffer.floatChannelData?[0] else { break }

            mixedBuffer.frameLength = frameCount
            for index in 0..<Int(frameCount) {
                let microphone = index < Int(microphoneBuffer.frameLength)
                    ? microphoneSamples[index] : 0
                let system = index < Int(systemBuffer.frameLength)
                    ? systemSamples[index] : 0
                mixedSamples[index] = max(-1, min(1, (microphone + system) * 0.5))
            }
            try outputFile.write(from: mixedBuffer)
        }
    }
}
