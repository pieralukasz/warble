import Foundation

/// Headless access to the same on-disk records as the app. Reads never repair or migrate data.
public struct DataCLI {
    public let dataDirectory: URL
    public let configFile: URL
    public let lockFile: URL

    public init(dataDirectory: URL = AppDirectories.applicationSupport,
                configFile: URL = Config.configFile, lockFile: URL = DaemonLock.defaultLockURL) {
        self.dataDirectory = dataDirectory
        self.configFile = configFile
        self.lockFile = lockFile
    }

    public struct Failure: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    public func run(_ args: [String]) throws -> String {
        if args == ["settings", "show"] {
            let config = try JSONFileStore<Config>(fileURL: configFile).load() ?? Config.defaultConfig
            return try Self.json(config)
        }
        if args == ["status"] {
            struct Status: Encodable {
                let version: String
                let dataDirectory: String
                let configFile: String
                let dictionaryCount: Int
                let historyCount: Int
            }
            return try Self.json(Status(version: AppInfo.version, dataDirectory: dataDirectory.path,
                configFile: configFile.path,
                dictionaryCount: JSONFileStore<[DictionaryEntry]>(fileURL: dataDirectory.appendingPathComponent("dictionary.json")).load()?.count ?? 0,
                historyCount: JSONFileStore<[HistoryEntry]>(fileURL: dataDirectory.appendingPathComponent("history.json")).load()?.count ?? 0))
        }
        if args.first == "history" { return try history(Array(args.dropFirst())) }
        guard args.count >= 3, args[0] == "dictionary",
              let kind = Self.kind(args[1]) else {
            throw Failure(message: "Use dictionary words|replacements list|add|remove. See --help.")
        }
        let store = JSONFileStore<[DictionaryEntry]>(fileURL: dataDirectory.appendingPathComponent("dictionary.json"))
        let action = args[2]
        if action == "list", args.count == 3 {
            return try Self.json((store.load() ?? []).filter { $0.kind == kind })
        }
        let expected = action == "add" && kind == .replacement ? 5 : 4
        guard ["add", "remove"].contains(action), args.count == expected else {
            throw Failure(message: "Expected add <word>, add <spoken> <written>, or remove <UUID>.")
        }
        let spoken = args[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let written = (kind == .word ? spoken : args.last!).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !written.isEmpty else { throw Failure(message: "Text must not be blank.") }
        if action == "remove", UUID(uuidString: args[3]) == nil { throw Failure(message: "Expected a dictionary entry UUID.") }
        return try withWriteLock {
            var entries = try store.load() ?? []
            let changed: DictionaryEntry
            if action == "add" {
                guard !entries.contains(where: { $0.kind == kind && $0.spoken.caseInsensitiveCompare(spoken) == .orderedSame }) else {
                    throw Failure(message: "Entry already exists; remove its UUID before replacing it.")
                }
                changed = DictionaryEntry(kind: kind, spoken: spoken, written: written)
                entries.insert(changed, at: 0)
            } else {
                guard let index = entries.firstIndex(where: { $0.kind == kind && $0.id == UUID(uuidString: args[3]) }) else {
                    throw Failure(message: "Dictionary entry not found in this category.")
                }
                changed = entries.remove(at: index)
            }
            try store.save(entries)
            guard try Self.json(store.load() ?? []) == Self.json(entries) else { throw Failure(message: "Dictionary read-back verification failed.") }
            return try Self.json(changed)
        }
    }

    private func history(_ args: [String]) throws -> String {
        let usage = Failure(message: "Use history list|export [--query <text>] [--limit <positive integer>], or history show <UUID>.")
        guard let action = args.first, ["list", "export", "show"].contains(action) else { throw usage }
        var query: String?
        var limit: Int?
        if action == "show" {
            guard args.count == 2, UUID(uuidString: args[1]) != nil else { throw usage }
        } else {
            var i = 1
            while i < args.count {
                guard i + 1 < args.count else { throw usage }
                switch args[i] {
                case "--query" where query == nil: query = args[i + 1]
                case "--limit" where limit == nil:
                    guard let n = Int(args[i + 1]), n > 0 else { throw usage }
                    limit = n
                default: throw usage
                }
                i += 2
            }
        }
        var entries = try JSONFileStore<[HistoryEntry]>(fileURL: dataDirectory.appendingPathComponent("history.json")).load() ?? []
        if action == "show" {
            guard let entry = entries.first(where: { $0.id == UUID(uuidString: args[1]) }) else {
                throw Failure(message: "History entry not found.")
            }
            return try Self.json(entry)
        }
        if let query {
            entries = entries.filter { $0.text.localizedCaseInsensitiveContains(query) || ($0.appName?.localizedCaseInsensitiveContains(query) ?? false) }
        }
        entries.sort { $0.date > $1.date }
        if let limit { entries = Array(entries.prefix(limit)) }
        return try Self.json(entries)
    }

    private static func kind(_ name: String) -> DictionaryEntry.Kind? {
        switch name {
        case "words": return .word
        case "replacements": return .replacement
        default: return nil
        }
    }

    private func withWriteLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: lockFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(lockFile.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw Failure(message: "Cannot open the data lock; refusing to write.") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            throw Failure(message: "Warble or another writer is running. Quit Warble before editing the dictionary.")
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    public static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
