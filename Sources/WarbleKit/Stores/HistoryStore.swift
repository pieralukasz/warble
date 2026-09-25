import Foundation
import Observation

@MainActor
@Observable
public final class HistoryStore {
    /// Keeps the file small enough to load instantly at launch.
    static let MAX_ENTRIES = 5_000

    public private(set) var entries: [HistoryEntry] = []
    /// Set when the file on disk could not be read at launch; it stays until relaunch.
    public private(set) var loadWarning: String?
    public private(set) var saveError: String?

    private let file: JSONFileStore<[HistoryEntry]>

    public init(fileURL: URL = AppDirectories.applicationSupportFile(named: "history.json")) {
        file = JSONFileStore(fileURL: fileURL)
        do {
            entries = try file.load() ?? []
        } catch {
            loadWarning = Self.describeUnreadableFile(file, error: error)
        }
    }

    public var stats: HistoryStats { HistoryStats.compute(from: entries) }

    public func add(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.MAX_ENTRIES {
            entries.removeLast(entries.count - Self.MAX_ENTRIES)
        }
        persist()
    }

    public func remove(id: HistoryEntry.ID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    public func removeAll() {
        entries = []
        persist()
    }

    public func search(_ query: String) -> [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.text.localizedCaseInsensitiveContains(trimmed)
                || ($0.appName?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private func persist() {
        do {
            try file.save(entries)
            saveError = nil
        } catch {
            saveError = "Could not save the history: \(error.localizedDescription)"
        }
    }

    private static func describeUnreadableFile(_ file: JSONFileStore<[HistoryEntry]>, error: Error) -> String {
        let reason = "Could not read the history: \(error.localizedDescription)"
        do {
            let backup = try file.quarantine()
            return "\(reason). The old file was kept as \(backup.lastPathComponent)."
        } catch {
            return "\(reason). Moving it aside also failed: \(error.localizedDescription)"
        }
    }
}
