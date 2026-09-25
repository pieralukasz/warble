import AppKit

/// Launches Warble on sample data with one screen open, for documentation
/// screenshots and visual checks. Real history, dictionary and settings are
/// never read or written in this mode. The window number is printed so the
/// screen can be captured with `screencapture -l <number>`.
///
///     WARBLE_PREVIEW=history Warble.app/Contents/MacOS/warble
public enum PreviewMode {
    public enum Scene: Equatable {
        case main(MainSectionName)
        case onboarding(step: Int)
        case pill(PillName)
    }

    public enum MainSectionName: String { case home, history, dictionary, settings }
    public enum PillName: String { case recording, transcribing, inserted, error }

    public static var scene: Scene? {
        guard let raw = ProcessInfo.processInfo.environment["WARBLE_PREVIEW"] else { return nil }
        return parse(raw)
    }

    public static var isActive: Bool { scene != nil }

    /// Accepts "home", "settings", "onboarding-3" or "pill-recording".
    public static func parse(_ raw: String) -> Scene? {
        let value = raw.lowercased()
        if let section = MainSectionName(rawValue: value) { return .main(section) }
        if value.hasPrefix("onboarding-"), let step = Int(value.dropFirst("onboarding-".count)) {
            return .onboarding(step: step)
        }
        if value.hasPrefix("pill-"), let pill = PillName(rawValue: String(value.dropFirst("pill-".count))) {
            return .pill(pill)
        }
        return nil
    }

    static var dataDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("warble-preview", isDirectory: true)
    }
}

extension PreviewMode.MainSectionName {
    var section: MainSection {
        switch self {
        case .home: return .home
        case .history: return .history
        case .dictionary: return .dictionary
        case .settings: return .settings
        }
    }
}

extension PreviewMode.PillName {
    var phase: DictationPhase {
        switch self {
        case .recording: return .recording
        case .transcribing: return .transcribing
        case .inserted: return .inserted
        case .error: return .error("Microphone unavailable")
        }
    }
}
