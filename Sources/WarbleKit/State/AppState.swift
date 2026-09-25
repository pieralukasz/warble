import Foundation
import Observation

/// Live state shared by the menu bar, the recording pill and every window.
@MainActor
@Observable
public final class AppState {
    /// Bars in the pill waveform; one new level arrives per audio buffer.
    public static let LEVEL_HISTORY_COUNT = 28

    public private(set) var phase: DictationPhase = .preparing
    public var model: ModelStatus = .notLoaded
    public private(set) var levels: [Float] = Array(repeating: 0, count: LEVEL_HISTORY_COUNT)
    /// Loudest level of the current or last recording, kept after the waveform
    /// is cleared so an empty transcription can tell silence from mumbling.
    public private(set) var recordingPeakLevel: Float = 0
    public var lastTranscription: String?
    public var hotkeySummary: String = ""

    private var resetTask: Task<Void, Never>?

    public init() {}

    /// Moves to `phase`. With `resetAfter`, returns to idle after that many
    /// seconds unless something else happened in between.
    public func transition(to phase: DictationPhase, resetAfter delay: TimeInterval? = nil) {
        resetTask?.cancel()
        resetTask = nil
        if phase == .recording && self.phase != .recording {
            recordingPeakLevel = 0
        }
        self.phase = phase
        if phase != .recording {
            resetLevels()
        }
        guard let delay else { return }

        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.phase == phase else { return }
            self.phase = .idle
        }
    }

    public func pushLevel(_ level: Float) {
        guard phase == .recording else { return }
        recordingPeakLevel = max(recordingPeakLevel, level)
        levels.removeFirst()
        levels.append(level)
    }

    private func resetLevels() {
        guard levels.contains(where: { $0 != 0 }) else { return }
        levels = Array(repeating: 0, count: Self.LEVEL_HISTORY_COUNT)
    }
}
