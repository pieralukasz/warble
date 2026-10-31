import Foundation

/// A modifier-only hotkey such as Right ⌘ is also part of everyday shortcuts,
/// and only its release tells a dictation press from a shortcut. A regular key
/// can act on press.
enum HotkeyKind: Equatable, Sendable {
    case modifier
    case key
}

struct RecordingLifecycle {
    enum Action: Equatable {
        case none
        case startRecording
        case stopRecording
        case cancelRecording
        case prepareRecorder
    }

    private(set) var isRecording = false

    mutating func keyDown(toggleMode: Bool, kind: HotkeyKind = .key) -> Action {
        if toggleMode {
            // Pressing Right ⌘ for Right ⌘ V must not start a recording, and
            // that is only known once the key comes back up.
            guard kind == .key else { return .none }
            return toggle()
        }

        guard !isRecording else { return .none }
        isRecording = true
        return .startRecording
    }

    /// `wasChord` is true when another key went down while the hotkey was held.
    mutating func keyUp(toggleMode: Bool, kind: HotkeyKind = .key, wasChord: Bool = false) -> Action {
        if toggleMode {
            guard kind == .modifier, !wasChord else { return .none }
            return toggle()
        }

        guard isRecording else { return .none }
        isRecording = false
        // Hold mode has to start on press; a shortcut found out on release is
        // dropped instead of typing whatever the microphone heard meanwhile.
        return wasChord ? .cancelRecording : .stopRecording
    }

    mutating func systemWillSleep() -> Action {
        guard isRecording else { return .none }
        isRecording = false
        return .cancelRecording
    }

    func systemDidWake(isReady: Bool) -> Action {
        isReady ? .prepareRecorder : .none
    }

    mutating func recordingStartFailed() {
        isRecording = false
    }

    private mutating func toggle() -> Action {
        isRecording.toggle()
        return isRecording ? .startRecording : .stopRecording
    }
}

enum RecordingCancellation {
    static func discardPartialRecording(at url: URL?, fileManager: FileManager = .default) {
        guard let url else { return }
        try? fileManager.removeItem(at: url)
    }

    static func discardTrackedPartialRecording(_ url: inout URL?, fileManager: FileManager = .default) {
        discardPartialRecording(at: url, fileManager: fileManager)
        url = nil
    }
}
