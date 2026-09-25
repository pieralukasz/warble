import Foundation

/// What the dictation pipeline is doing right now. Drives the menu bar icon,
/// the floating pill and the status line in the main window.
public enum DictationPhase: Equatable, Sendable {
    /// Launching: loading Parakeet or waiting for permissions.
    case preparing
    case needsAccessibility
    case idle
    case recording
    case transcribing
    /// Text was typed at the cursor; shown briefly before returning to idle.
    case inserted
    /// A re-transcription landed on the clipboard instead of being typed.
    case copied
    case error(String)

    public var isBusy: Bool {
        self == .recording || self == .transcribing
    }

    public var statusText: String {
        switch self {
        case .preparing: return "Getting ready"
        case .needsAccessibility: return "Needs Accessibility permission"
        case .idle: return "Ready"
        case .recording: return "Listening"
        case .transcribing: return "Transcribing"
        case .inserted: return "Typed"
        case .copied: return "Copied to clipboard"
        case .error(let message): return message
        }
    }
}

/// Where the Parakeet model is on its way from Hugging Face to memory.
public enum ModelStatus: Equatable, Sendable {
    case notLoaded
    /// `fraction` is nil while the size of the download is still unknown.
    case loading(fraction: Double?, detail: String)
    case ready
    case failed(String)

    public var isReady: Bool { self == .ready }
}
