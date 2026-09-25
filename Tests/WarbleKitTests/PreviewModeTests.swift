import XCTest
@testable import WarbleKit

final class PreviewModeTests: XCTestCase {
    func testParsesEveryKindOfScene() {
        XCTAssertEqual(PreviewMode.parse("History"), .main(.history))
        XCTAssertEqual(PreviewMode.parse("onboarding-3"), .onboarding(step: 3))
        XCTAssertEqual(PreviewMode.parse("pill-transcribing"), .pill(.transcribing))
    }

    func testRejectsUnknownScenes() {
        XCTAssertNil(PreviewMode.parse("dashboard"))
        XCTAssertNil(PreviewMode.parse("onboarding-x"))
        XCTAssertNil(PreviewMode.parse("pill-sleeping"))
    }
}
