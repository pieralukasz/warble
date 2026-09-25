import AppKit
import Foundation

/// Turns hotkey presses into typed text: record, transcribe, clean up, insert,
/// and remember the result in the history.
@MainActor
final class DictationController {
    struct Dependencies {
        let appState: AppState
        let history: HistoryStore
        let dictionary: DictionaryStore
        let recorder: AudioRecorder
        let sounds: SoundPlayer
    }

    /// Where the audio goes and what the user was typing into when they pressed the key.
    private struct Session {
        let startedAt: Date
        let audioURL: URL
        let keepsAudio: Bool
        let appName: String?
        let appBundleID: String?
    }

    /// Pressing and releasing faster than this is almost always an accidental tap.
    static let MINIMUM_RECORDING_SECONDS = 0.25
    static let CONFIRMATION_SECONDS = 1.2
    static let ERROR_SECONDS = 5.0

    private let deps: Dependencies
    private var lifecycle = RecordingLifecycle()
    private var startTask: Task<Bool, Never>?
    private var session: Session?

    var config: Config
    var transcriber: ParakeetTranscriber
    var inserter = TextInserter()
    var onCaptureFailure: ((Error) -> Void)?

    init(dependencies: Dependencies, config: Config, transcriber: ParakeetTranscriber) {
        self.deps = dependencies
        self.config = config
        self.transcriber = transcriber
    }

    private var isToggleMode: Bool { config.toggleMode?.value ?? false }

    func handleKeyDown() {
        guard deps.appState.phase == .idle || deps.appState.phase == .recording || isTransient else { return }
        switch lifecycle.keyDown(toggleMode: isToggleMode) {
        case .startRecording: startRecording()
        case .stopRecording: stopRecording()
        case .none, .cancelRecording, .prepareRecorder: break
        }
    }

    func handleKeyUp() {
        if lifecycle.keyUp(toggleMode: isToggleMode) == .stopRecording {
            stopRecording()
        }
    }

    /// Drops the recording in progress when the Mac goes to sleep mid-dictation.
    func cancelForSleep() {
        guard lifecycle.systemWillSleep() == .cancelRecording else { return }
        startTask?.cancel()
        startTask = nil
        deps.recorder.teardown()
        discardSessionAudio()
        deps.appState.transition(to: .idle)
    }

    /// Transcribes a saved recording again and copies the result.
    func retranscribe(audioURL: URL) {
        guard deps.appState.phase == .idle || isTransient else { return }
        deps.appState.transition(to: .transcribing)
        Task {
            do {
                let text = try await transcribe(audioURL)
                copyToClipboard(text)
                deps.appState.lastTranscription = text
                deps.appState.transition(to: .copied, resetAfter: Self.CONFIRMATION_SECONDS)
            } catch {
                report(error)
            }
        }
    }

    private var isTransient: Bool {
        switch deps.appState.phase {
        case .inserted, .copied, .error: return true
        default: return false
        }
    }

    private func startRecording() {
        let keepsAudio = Config.effectiveMaxRecordings(config.maxRecordings) > 0
        let url = keepsAudio ? RecordingStore.newRecordingURL() : RecordingStore.tempRecordingURL()
        let frontmost = NSWorkspace.shared.frontmostApplication
        session = Session(
            startedAt: Date(),
            audioURL: url,
            keepsAudio: keepsAudio,
            appName: frontmost?.localizedName,
            appBundleID: frontmost?.bundleIdentifier
        )
        deps.appState.transition(to: .recording)
        deps.sounds.play(.start)

        let recorder = deps.recorder
        startTask = Task {
            do {
                try await recorder.startRecording(to: url)
                return true
            } catch {
                lifecycle.recordingStartFailed()
                discardSessionAudio()
                report(error)
                onCaptureFailure?(error)
                return false
            }
        }
    }

    private func stopRecording() {
        let pendingStart = startTask
        startTask = nil
        guard let session else { return }
        self.session = nil
        deps.sounds.play(.stop)
        deps.appState.transition(to: .transcribing)

        Task {
            guard await pendingStart?.value ?? true,
                  let audioURL = await deps.recorder.stopRecording() else {
                RecordingCancellation.discardPartialRecording(at: session.audioURL)
                if case .error = deps.appState.phase { return }
                deps.appState.transition(to: .idle)
                return
            }
            await finish(session, audioURL: audioURL)
        }
    }

    private func finish(_ session: Session, audioURL: URL) async {
        defer {
            if !session.keepsAudio { try? FileManager.default.removeItem(at: audioURL) }
        }
        let duration = Date().timeIntervalSince(session.startedAt)
        guard duration >= Self.MINIMUM_RECORDING_SECONDS else {
            deps.appState.transition(to: .idle)
            return
        }

        do {
            let text = try await transcribe(audioURL)
            if session.keepsAudio {
                RecordingStore.prune(maxCount: Config.effectiveMaxRecordings(config.maxRecordings))
            }
            guard !text.isEmpty else {
                reportSilence()
                return
            }
            inserter.insert(text: text)
            record(text, session: session, duration: duration, audioURL: audioURL)
            deps.appState.transition(to: .inserted, resetAfter: Self.CONFIRMATION_SECONDS)
        } catch {
            report(error)
        }
    }

    private func transcribe(_ audioURL: URL) async throws -> String {
        let transcriber = self.transcriber
        let raw = try await Task.detached(priority: .userInitiated) {
            try transcriber.transcribe(audioURL: audioURL)
        }.value
        let punctuated = (config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
        return deps.dictionary.apply(to: punctuated)
    }

    private func record(_ text: String, session: Session, duration: TimeInterval, audioURL: URL) {
        deps.appState.lastTranscription = text
        deps.history.add(HistoryEntry(
            date: session.startedAt,
            text: text,
            durationSeconds: duration,
            audioFileName: session.keepsAudio ? audioURL.lastPathComponent : nil,
            appName: session.appName,
            appBundleID: session.appBundleID
        ))
    }

    private func report(_ error: Error) {
        let message = (error as? AudioCaptureError)?.shortDescription ?? error.localizedDescription
        print("Dictation error: \(error.localizedDescription)")
        deps.sounds.play(.failure)
        deps.appState.transition(to: .error(message), resetAfter: Self.ERROR_SECONDS)
    }

    /// An empty transcription used to hide the pill without a word, which looked
    /// exactly like a recording that worked but went nowhere.
    private func reportSilence() {
        let message = SilentDictation.message(
            source: config.audioCaptureSource,
            peakLevel: deps.appState.recordingPeakLevel
        )
        print("Dictation produced no text: \(message)")
        deps.sounds.play(.failure)
        deps.appState.transition(to: .error(message), resetAfter: Self.ERROR_SECONDS)
    }

    private func discardSessionAudio() {
        RecordingCancellation.discardPartialRecording(at: session?.audioURL)
        session = nil
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
