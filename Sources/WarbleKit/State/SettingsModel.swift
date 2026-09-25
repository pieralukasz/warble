import Foundation
import Observation

/// The config as the UI sees it. Every edit is saved and handed to the app
/// immediately, so there is no Apply button anywhere.
@MainActor
@Observable
public final class SettingsModel {
    public private(set) var config: Config
    public private(set) var saveError: String?

    private let onChange: (Config) -> Void
    /// False in preview mode, so screenshots never touch the real config file.
    private let persists: Bool

    public init(config: Config, persists: Bool = true, onChange: @escaping (Config) -> Void) {
        self.config = config
        self.persists = persists
        self.onChange = onChange
    }

    public func update(_ edit: (inout Config) -> Void) {
        var next = config
        edit(&next)
        do {
            if persists { try next.save() }
            saveError = nil
        } catch {
            saveError = "Could not save settings: \(error.localizedDescription)"
            return
        }
        config = next
        onChange(next)
    }

    /// Picks up a config that changed outside the UI, e.g. from the CLI.
    public func replace(with config: Config) {
        self.config = config
    }

    public var isToggleMode: Bool { config.toggleMode?.value ?? false }
    public var showsPill: Bool { config.shouldShowRecordingPill?.value ?? true }
    public var playsSounds: Bool { config.shouldPlaySounds?.value ?? true }
    public var usesSpokenPunctuation: Bool { config.spokenPunctuation?.value ?? false }
    public var keptRecordings: Int { Config.effectiveMaxRecordings(config.maxRecordings) }
}
