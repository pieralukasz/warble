import XCTest
@testable import WarbleKit

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() async throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("warble-history-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testAddedEntriesSurviveReload() {
        let store = HistoryStore(fileURL: fileURL)
        store.add(HistoryEntry(text: "first", durationSeconds: 1))
        store.add(HistoryEntry(text: "second", durationSeconds: 1))

        let reloaded = HistoryStore(fileURL: fileURL)

        XCTAssertEqual(reloaded.entries.map(\.text), ["second", "first"])
        XCTAssertNil(reloaded.loadWarning)
        XCTAssertNil(reloaded.saveError)
    }

    func testSearchMatchesTextAndAppName() {
        let store = HistoryStore(fileURL: fileURL)
        store.add(HistoryEntry(text: "Ship the release", durationSeconds: 1, appName: "Slack"))
        store.add(HistoryEntry(text: "Buy milk", durationSeconds: 1, appName: "Notes"))

        XCTAssertEqual(store.search("release").map(\.text), ["Ship the release"])
        XCTAssertEqual(store.search("notes").map(\.text), ["Buy milk"])
        XCTAssertEqual(store.search("  ").count, 2)
    }

    func testRemoveAndRemoveAll() {
        let store = HistoryStore(fileURL: fileURL)
        let kept = HistoryEntry(text: "keep", durationSeconds: 1)
        let dropped = HistoryEntry(text: "drop", durationSeconds: 1)
        store.add(kept)
        store.add(dropped)

        store.remove(id: dropped.id)
        XCTAssertEqual(store.entries, [kept])

        store.removeAll()
        XCTAssertTrue(HistoryStore(fileURL: fileURL).entries.isEmpty)
    }

    func testCorruptFileIsMovedAsideInsteadOfOverwritten() throws {
        try Data("not json".utf8).write(to: fileURL)

        let store = HistoryStore(fileURL: fileURL)
        store.add(HistoryEntry(text: "fresh", durationSeconds: 1))

        let folder = fileURL.deletingLastPathComponent()
        let base = fileURL.deletingPathExtension().lastPathComponent
        let backups = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix("\(base).corrupt-") }
        XCTAssertEqual(backups.count, 1)
        let backupURL = folder.appendingPathComponent(backups[0])
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), "not json")
        XCTAssertTrue(store.loadWarning?.contains(backups[0]) ?? false)
        XCTAssertEqual(HistoryStore(fileURL: fileURL).entries.map(\.text), ["fresh"])
        try FileManager.default.removeItem(at: backupURL)
    }
}
