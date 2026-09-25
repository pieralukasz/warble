import XCTest
@testable import WarbleKit

final class LegacyConfigMigrationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("warble-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testCopiesLegacyConfigWhenTargetIsMissing() throws {
        let legacy = root.appendingPathComponent("open-wispr/config.json")
        let target = root.appendingPathComponent("warble/config.json")
        try FileManager.default.createDirectory(
            at: legacy.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"language":"pl"}"#.utf8).write(to: legacy)

        let outcome = try LegacyConfigMigration.migrateIfNeeded(from: legacy, to: target)

        XCTAssertEqual(outcome, .migrated)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), #"{"language":"pl"}"#)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
    }

    func testLeavesExistingTargetUntouched() throws {
        let legacy = root.appendingPathComponent("legacy.json")
        let target = root.appendingPathComponent("target.json")
        try Data("legacy".utf8).write(to: legacy)
        try Data("current".utf8).write(to: target)

        let outcome = try LegacyConfigMigration.migrateIfNeeded(from: legacy, to: target)

        XCTAssertEqual(outcome, .skippedTargetExists)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "current")
    }

    func testSkipsWhenNoLegacyConfigExists() throws {
        let legacy = root.appendingPathComponent("missing.json")
        let target = root.appendingPathComponent("target.json")

        let outcome = try LegacyConfigMigration.migrateIfNeeded(from: legacy, to: target)

        XCTAssertEqual(outcome, .skippedNoLegacyConfig)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
}
