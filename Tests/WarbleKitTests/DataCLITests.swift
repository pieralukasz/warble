import XCTest
@testable import WarbleKit

final class DataCLITests: XCTestCase {
    func testInvocationIsolationAndStrictFlags() throws {
        let invocation = try DataCLIInvocation(arguments: ["--data-dir", "/example", "--json", "dictionary", "words", "add", "--json"])
        XCTAssertEqual(invocation.arguments.last, "--json")
        XCTAssertEqual(invocation.cli.configFile.path, "/example/config.json")
        XCTAssertThrowsError(try DataCLIInvocation(arguments: ["--data-dir", ""]))
        XCTAssertThrowsError(try DataCLIInvocation(arguments: ["--data-dir", "/example", "start"]))
        XCTAssertThrowsError(try DataCLIInvocation(arguments: ["--json", "set-language", "pl"]))
    }

    func testReadOnlyHistorySettingsAndCorruption() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cli = DataCLI(dataDirectory: root, configFile: root.appendingPathComponent("config.json"), lockFile: root.appendingPathComponent("daemon.lock"))
        XCTAssertTrue(try cli.run(["settings", "show"]).contains("language"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        let entries = [HistoryEntry(text: "Hello Łukasz", durationSeconds: 2, appName: "Notes"), HistoryEntry(text: "Other", durationSeconds: 1)]
        try JSONFileStore<[HistoryEntry]>(fileURL: root.appendingPathComponent("history.json")).save(entries)
        let output = try cli.run(["history", "list", "--query", "notes", "--limit", "1"])
        XCTAssertTrue(output.contains("Hello Łukasz"))
        XCTAssertFalse(output.contains("Other"))
        XCTAssertTrue(try cli.run(["history", "show", entries[0].id.uuidString]).contains("Hello Łukasz"))
        XCTAssertTrue(try cli.run(["history", "export"]).contains("Other"))
        XCTAssertThrowsError(try cli.run(["history", "list", "--limit", "0"]))
        let broken = Data("broken".utf8)
        try broken.write(to: root.appendingPathComponent("dictionary.json"))
        XCTAssertThrowsError(try cli.run(["dictionary", "words", "list"]))
        XCTAssertThrowsError(try cli.run(["dictionary", "words", "add", "Test"]))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("dictionary.json")), broken)
    }

    func testDictionaryRoundTripAndValidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cli = DataCLI(dataDirectory: root, configFile: root.appendingPathComponent("config.json"), lockFile: root.appendingPathComponent("daemon.lock"))
        let added = try cli.run(["dictionary", "words", "add", " GitHub "])
        let entry = try JSONDecoder().decode(JSONValue.self, from: Data(added.utf8))
        XCTAssertTrue(entry.raw.contains("GitHub"))
        XCTAssertThrowsError(try cli.run(["dictionary", "words", "add", " "]))
        XCTAssertThrowsError(try cli.run(["dictionary", "words", "add", "GitHub"]))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([DictionaryEntry].self, from: Data(cli.run(["dictionary", "words", "list"]).utf8))
        XCTAssertEqual(entries.count, 1)
        _ = try cli.run(["dictionary", "words", "remove", entries[0].id.uuidString])
        XCTAssertEqual(try cli.run(["dictionary", "words", "list"]), "[\n\n]")
    }
}

private struct JSONValue: Decodable {
    let raw: String
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        raw = try c.decode(String.self, forKey: .written)
    }
    enum Keys: String, CodingKey { case written }
}
