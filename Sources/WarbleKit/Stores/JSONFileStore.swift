import Foundation

/// Reads and writes one Codable value as a JSON file under Application Support.
struct JSONFileStore<Value: Codable> {
    let fileURL: URL

    /// Returns nil when the file does not exist yet. A file that exists but
    /// cannot be decoded throws; callers then call `quarantine()` so a later
    /// save never overwrites data they failed to read.
    func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: fileURL, options: .atomic)
    }

    /// Moves an unreadable file aside and returns where it went.
    func quarantine(now: Date = Date()) throws -> URL {
        let stamp = Int(now.timeIntervalSince1970)
        let base = fileURL.deletingPathExtension().lastPathComponent
        let destination = fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(base).corrupt-\(stamp).json")
        try FileManager.default.moveItem(at: fileURL, to: destination)
        return destination
    }
}
