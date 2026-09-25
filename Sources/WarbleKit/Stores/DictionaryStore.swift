import Foundation
import Observation

@MainActor
@Observable
public final class DictionaryStore {
    public private(set) var entries: [DictionaryEntry] = []
    /// Set when the file on disk could not be read at launch; it stays until relaunch.
    public private(set) var loadWarning: String?
    public private(set) var saveError: String?

    private let file: JSONFileStore<[DictionaryEntry]>

    public init(fileURL: URL = AppDirectories.applicationSupportFile(named: "dictionary.json")) {
        file = JSONFileStore(fileURL: fileURL)
        do {
            entries = try file.load() ?? []
        } catch {
            loadWarning = Self.describeUnreadableFile(file, error: error)
        }
    }

    public var words: [DictionaryEntry] { entries.filter { $0.kind == .word } }
    public var replacements: [DictionaryEntry] { entries.filter { $0.kind == .replacement } }

    public func add(_ entry: DictionaryEntry) {
        let spoken = entry.spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        var cleaned = entry
        cleaned.spoken = spoken
        cleaned.written = entry.written.trimmingCharacters(in: .whitespacesAndNewlines)
        entries.removeAll { $0.kind == cleaned.kind && $0.spoken.caseInsensitiveCompare(spoken) == .orderedSame }
        entries.insert(cleaned, at: 0)
        persist()
    }

    public func remove(id: DictionaryEntry.ID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    public func apply(to text: String) -> String {
        DictionaryEngine.apply(entries, to: text)
    }

    private func persist() {
        do {
            try file.save(entries)
            saveError = nil
        } catch {
            saveError = "Could not save the dictionary: \(error.localizedDescription)"
        }
    }

    private static func describeUnreadableFile(_ file: JSONFileStore<[DictionaryEntry]>, error: Error) -> String {
        let reason = "Could not read the dictionary: \(error.localizedDescription)"
        do {
            let backup = try file.quarantine()
            return "\(reason). The old file was kept as \(backup.lastPathComponent)."
        } catch {
            return "\(reason). Moving it aside also failed: \(error.localizedDescription)"
        }
    }
}
