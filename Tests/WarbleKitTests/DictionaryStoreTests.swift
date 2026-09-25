import XCTest
@testable import WarbleKit

@MainActor
final class DictionaryStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() async throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("warble-dictionary-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testEntriesAreTrimmedPersistedAndSplitByKind() {
        let store = DictionaryStore(fileURL: fileURL)
        store.add(.word("  Warble "))
        store.add(.replacement("my site", with: " warble.app "))

        let reloaded = DictionaryStore(fileURL: fileURL)

        XCTAssertEqual(reloaded.words.map(\.spoken), ["Warble"])
        XCTAssertEqual(reloaded.replacements.map(\.written), ["warble.app"])
    }

    func testAddingSameSpokenPhraseReplacesPreviousRule() {
        let store = DictionaryStore(fileURL: fileURL)
        store.add(.replacement("my email", with: "old@example.com"))
        store.add(.replacement("My Email", with: "new@example.com"))

        XCTAssertEqual(store.replacements.count, 1)
        XCTAssertEqual(store.apply(to: "write my email"), "write new@example.com")
    }

    func testBlankEntryIsRejected() {
        let store = DictionaryStore(fileURL: fileURL)

        store.add(.replacement("   ", with: "anything"))

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testRemoveDeletesOnlyThatEntry() {
        let store = DictionaryStore(fileURL: fileURL)
        store.add(.word("Kubernetes"))
        store.add(.word("SwiftUI"))
        let target = try! XCTUnwrap(store.words.first { $0.spoken == "Kubernetes" })

        store.remove(id: target.id)

        XCTAssertEqual(DictionaryStore(fileURL: fileURL).words.map(\.spoken), ["SwiftUI"])
    }
}
