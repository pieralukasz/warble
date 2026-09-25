import Foundation

/// Carries settings over from the open-wispr fork Warble grew out of, so an
/// existing hotkey, language and microphone choice survive the rename.
public enum LegacyConfigMigration {
    public static var legacyConfigFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/open-wispr/config.json")
    }

    public enum Outcome: Equatable {
        case migrated
        case skippedTargetExists
        case skippedNoLegacyConfig
    }

    /// Copies the legacy file only when Warble has no config of its own yet.
    /// The legacy file is left in place so the old app keeps working.
    @discardableResult
    public static func migrateIfNeeded(
        from legacyFile: URL = legacyConfigFile,
        to targetFile: URL = Config.configFile
    ) throws -> Outcome {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: targetFile.path) { return .skippedTargetExists }
        guard fileManager.fileExists(atPath: legacyFile.path) else { return .skippedNoLegacyConfig }

        try fileManager.createDirectory(
            at: targetFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: legacyFile, to: targetFile)
        return .migrated
    }
}
