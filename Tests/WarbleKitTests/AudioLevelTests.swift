import XCTest
@testable import WarbleKit

final class AudioLevelTests: XCTestCase {
    func testRMSOfConstantSignalEqualsItsMagnitude() {
        let samples: [Float] = [0.5, -0.5, 0.5, -0.5]

        let rms = samples.withUnsafeBufferPointer { AudioLevel.rms(of: $0) }

        XCTAssertEqual(rms, 0.5, accuracy: 0.0001)
    }

    func testRMSOfEmptyBufferIsZero() {
        let samples: [Float] = []

        let rms = samples.withUnsafeBufferPointer { AudioLevel.rms(of: $0) }

        XCTAssertEqual(rms, 0)
    }

    func testFullScaleSignalNormalizesToOne() {
        XCTAssertEqual(AudioLevel.normalized(rms: 1), 1, accuracy: 0.0001)
    }

    func testSilenceAndNoiseFloorNormalizeToZero() {
        XCTAssertEqual(AudioLevel.normalized(rms: 0), 0)
        XCTAssertEqual(AudioLevel.normalized(rms: 0.000_01), 0)
    }

    func testMidLevelSignalLandsBetweenBounds() {
        let level = AudioLevel.normalized(rms: 0.05)

        XCTAssertGreaterThan(level, 0.3)
        XCTAssertLessThan(level, 0.8)
    }
}
