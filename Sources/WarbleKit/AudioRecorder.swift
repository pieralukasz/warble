import AVFoundation
import CoreAudio
import CoreMedia
import Foundation
import ScreenCaptureKit

class AudioRecorder {
    /// About 20 ms at 48 kHz, small enough for a smooth waveform.
    static let TAP_BUFFER_FRAMES: AVAudioFrameCount = 1024

    private let systemAudioQueue = DispatchQueue(
        label: "io.github.pieralukasz.warble.system-audio",
        qos: .userInitiated
    )
    private var audioEngine: AVAudioEngine?
    private var microphoneSink: MonoAudioFileSink?
    private var systemAudioSink: MonoAudioFileSink?
    private var systemAudioOutput: SystemAudioStreamOutput?
    private var systemAudioStream: SCStream?
    private var isRecording = false
    private var currentOutputURL: URL?
    private var microphoneOutputURL: URL?
    private var systemAudioOutputURL: URL?

    var preferredDeviceID: AudioDeviceID?
    var captureSource: AudioCaptureSource = .microphone
    /// Receives 0...1 loudness per audio buffer, on the audio thread.
    var levelHandler: ((Float) -> Void)?

    /// Stop and release all capture resources. Call before changing source/device or on shutdown.
    func teardown() {
        if isRecording {
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        audioEngine?.stop()
        audioEngine = nil

        systemAudioStream?.stopCapture { _ in }
        systemAudioStream = nil
        systemAudioOutput = nil
        microphoneSink?.close()
        systemAudioSink?.close()
        microphoneSink = nil
        systemAudioSink = nil
        cleanupTemporarySources()

        isRecording = false
        currentOutputURL = nil
    }

    /// Release capture resources after changing source/device or waking from sleep.
    func reload() {
        teardown()
    }

    func startRecording(to outputURL: URL) async throws {
        guard !isRecording else { return }

        currentOutputURL = outputURL
        let urls = sourceURLs(for: outputURL, source: captureSource)
        microphoneOutputURL = urls.microphone
        systemAudioOutputURL = urls.systemAudio

        do {
            try Task.checkCancellation()
            if captureSource.includesSystemAudio, let systemURL = systemAudioOutputURL {
                try await startSystemAudioRecording(to: systemURL)
            }
            try Task.checkCancellation()
            if captureSource.includesMicrophone, let microphoneURL = microphoneOutputURL {
                try startMicrophoneRecording(to: microphoneURL)
            }
            isRecording = true
        } catch {
            teardown()
            throw error
        }
    }

    func stopRecording() async -> URL? {
        guard isRecording, let outputURL = currentOutputURL else { return nil }
        isRecording = false

        if captureSource.includesMicrophone {
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            audioEngine = nil
            microphoneSink?.close()
            microphoneSink = nil
        }

        if let stream = systemAudioStream {
            try? await stream.stopCapture()
            await withCheckedContinuation { continuation in
                systemAudioQueue.async {
                    continuation.resume()
                }
            }
            systemAudioSink?.close()
            systemAudioSink = nil
            systemAudioOutput = nil
            systemAudioStream = nil
        }

        currentOutputURL = nil

        if captureSource == .microphoneAndSystemAudio,
           let microphoneURL = microphoneOutputURL,
           let systemAudioURL = systemAudioOutputURL {
            do {
                try Self.mixAudioFiles(
                    microphoneURL: microphoneURL,
                    systemAudioURL: systemAudioURL,
                    outputURL: outputURL
                )
            } catch {
                print("Warning: failed to mix microphone and system audio: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: outputURL)
                try? FileManager.default.copyItem(at: microphoneURL, to: outputURL)
            }
            cleanupTemporarySources()
        }

        microphoneOutputURL = nil
        systemAudioOutputURL = nil
        return outputURL
    }

    private func startMicrophoneRecording(to outputURL: URL) throws {
        if audioEngine == nil {
            let engine = AVAudioEngine()
            if let deviceID = preferredDeviceID,
               deviceID != AudioDeviceManager.getDefaultInputDeviceID() {
                setInputDevice(deviceID, on: engine)
            }
            _ = engine.inputNode
            engine.prepare()
            audioEngine = engine
        }

        guard let engine = audioEngine else {
            throw AudioCaptureError.microphoneEngineUnavailable
        }

        let sink = try MonoAudioFileSink(url: outputURL, onLevel: levelHandler)
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: Self.TAP_BUFFER_FRAMES, format: inputFormat) { buffer, _ in
            sink.append(buffer)
        }

        do {
            try engine.start()
            microphoneSink = sink
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            sink.close()
            throw error
        }
    }

    /// ScreenCaptureKit reports a missing Screen Recording grant as an
    /// SCStreamErrorDomain error whose message is the unreadable "The user declined
    /// TCCs for application, window, display capture". The grant is re-checked
    /// instead of matching on the error code alone, because the same condition also
    /// arrives under other codes when the grant is revoked mid-session.
    private static func mapSystemAudioError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == SCStreamErrorDomain else { return error }
        guard nsError.code == SCStreamError.Code.userDeclined.rawValue
            || !Permissions.hasScreenRecording else {
            return error
        }
        return AudioCaptureError.screenRecordingPermissionRequired
    }

    private func startSystemAudioRecording(to outputURL: URL) async throws {
        guard Permissions.ensureScreenRecording() else {
            throw AudioCaptureError.screenRecordingPermissionRequired
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw Self.mapSystemAudioError(error)
        }

        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() })
            ?? content.displays.first else {
            throw AudioCaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 16_000
        configuration.channelCount = 1
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.queueDepth = 1

        let meter = captureSource.includesMicrophone ? nil : levelHandler
        let sink = try MonoAudioFileSink(url: outputURL, onLevel: meter)
        let output = SystemAudioStreamOutput(sink: sink)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: systemAudioQueue)

        do {
            try await stream.startCapture()
            systemAudioSink = sink
            systemAudioOutput = output
            systemAudioStream = stream
        } catch {
            sink.close()
            throw Self.mapSystemAudioError(error)
        }
    }

    private func sourceURLs(
        for outputURL: URL,
        source: AudioCaptureSource
    ) -> (microphone: URL?, systemAudio: URL?) {
        switch source {
        case .microphone:
            return (outputURL, nil)
        case .systemAudio:
            return (nil, outputURL)
        case .microphoneAndSystemAudio:
            let directory = outputURL.deletingLastPathComponent()
            let token = UUID().uuidString
            return (
                directory.appendingPathComponent(".warble-\(token)-microphone.wav"),
                directory.appendingPathComponent(".warble-\(token)-system.wav")
            )
        }
    }

    private func cleanupTemporarySources() {
        guard captureSource == .microphoneAndSystemAudio else { return }
        for url in [microphoneOutputURL, systemAudioOutputURL].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
        microphoneOutputURL = nil
        systemAudioOutputURL = nil
    }

    private func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) {
        guard let audioUnit = engine.inputNode.audioUnit else {
            print("Warning: could not access audio unit to set input device")
            return
        }

        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            print("Warning: failed to set audio input device (status: \(status))")
        }
    }
}
