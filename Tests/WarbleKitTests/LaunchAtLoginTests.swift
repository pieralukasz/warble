import XCTest
@testable import WarbleKit

final class LaunchAtLoginTests: XCTestCase {

    private func decodePlist(executablePath: String) throws -> [String: Any] {
        let data = try LaunchAtLogin.makePlistData(executablePath: executablePath)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(plist as? [String: Any])
    }

    // MARK: - Plist contents

    func testPlistRunsTheGivenExecutableWithStart() throws {
        let path = "/Users/tester/Applications/Warble.app/Contents/MacOS/warble"

        let plist = try decodePlist(executablePath: path)

        XCTAssertEqual(plist["ProgramArguments"] as? [String], [path, "start"])
    }

    func testPlistUsesTheBundleIdentifierAsLabel() throws {
        let plist = try decodePlist(executablePath: "/tmp/warble")

        XCTAssertEqual(plist["Label"] as? String, "io.github.pieralukasz.warble")
        XCTAssertEqual(LaunchAtLogin.label, "io.github.pieralukasz.warble")
    }

    func testPlistRunsAtLoadAsAnInteractiveJob() throws {
        let plist = try decodePlist(executablePath: "/tmp/warble")

        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["ProcessType"] as? String, "Interactive")
    }

    func testPlistOmitsKeepAliveSoQuitIsRespected() throws {
        let plist = try decodePlist(executablePath: "/tmp/warble")

        XCTAssertNil(plist["KeepAlive"])
    }

    // MARK: - Plist location

    func testPlistLivesInTheUserLaunchAgentsDirectory() {
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/io.github.pieralukasz.warble.plist")

        XCTAssertEqual(LaunchAtLogin.plistURL, expected)
    }

    // MARK: - Enable failure path

    func testEnableRejectsAnExecutableOutsideAnAppBundle() {
        XCTAssertThrowsError(try LaunchAtLogin.enable(executablePath: nil)) { error in
            XCTAssertEqual(error as? LaunchAtLogin.Failure, .executableNotInAppBundle)
        }
    }
}
