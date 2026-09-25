import XCTest
@testable import WarbleKit

final class SilentDictationTests: XCTestCase {
    func testQuietMicrophoneIsNamed() {
        let message = SilentDictation.message(source: .microphone, peakLevel: 0)

        XCTAssertEqual(message, "No sound from the microphone")
    }

    func testQuietSystemAudioIsNamed() {
        let message = SilentDictation.message(source: .systemAudio, peakLevel: 0.02)

        XCTAssertEqual(message, "No sound from system audio")
    }

    func testAudibleRecordingWithoutWordsSaysSo() {
        let message = SilentDictation.message(source: .microphone, peakLevel: 0.6)

        XCTAssertEqual(message, "No words recognized")
    }
}
