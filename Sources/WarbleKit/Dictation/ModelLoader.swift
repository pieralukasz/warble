import FluidAudio
import Foundation

extension ModelStatus {
    /// Human wording for FluidAudio's download phases.
    public static func loading(from progress: DownloadProgress) -> ModelStatus {
        let fraction = min(max(progress.fractionCompleted, 0), 1)
        switch progress.phase {
        case .listing:
            return .loading(fraction: nil, detail: "Checking model files")
        case .downloading(let completed, let total):
            return .loading(fraction: fraction, detail: "Downloading Parakeet v3 · \(completed) of \(total) files")
        case .compiling:
            return .loading(fraction: fraction, detail: "Optimizing the model for this Mac")
        }
    }
}

/// Downloads Parakeet on first launch and loads it into memory, reporting
/// progress to `AppState` for onboarding and the Home screen.
@MainActor
final class ModelLoader {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    /// Returns true once the model is ready. Safe to call again after a failure.
    func load(using transcriber: ParakeetTranscriber) async -> Bool {
        if ParakeetTranscriber.isModelLoaded {
            appState.model = .ready
            return true
        }
        appState.model = .loading(fraction: nil, detail: "Loading Parakeet v3")

        let state = appState
        let reportProgress: ProgressHandler = { progress in
            Task { @MainActor in
                guard !state.model.isReady else { return }
                state.model = .loading(from: progress)
            }
        }

        do {
            try await Task.detached(priority: .userInitiated) {
                try transcriber.prepare(progress: reportProgress)
            }.value
            appState.model = .ready
            return true
        } catch {
            print("Model load failed: \(error.localizedDescription)")
            appState.model = .failed(error.localizedDescription)
            return false
        }
    }
}
