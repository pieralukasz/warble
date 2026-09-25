import XCTest
@testable import WarbleKit

@MainActor
final class AppStateTests: XCTestCase {
    func testLevelsOnlyMoveWhileRecording() {
        let state = AppState()
        state.transition(to: .idle)

        state.pushLevel(0.8)
        XCTAssertEqual(state.levels.last, 0)

        state.transition(to: .recording)
        state.pushLevel(0.8)
        XCTAssertEqual(state.levels.last, 0.8)
        XCTAssertEqual(state.levels.count, AppState.LEVEL_HISTORY_COUNT)
    }

    func testLeavingRecordingClearsTheWaveform() {
        let state = AppState()
        state.transition(to: .recording)
        state.pushLevel(0.5)

        state.transition(to: .transcribing)

        XCTAssertTrue(state.levels.allSatisfy { $0 == 0 })
    }

    func testPeakLevelCoversTheWholeRecording() {
        let state = AppState()
        state.transition(to: .recording)
        state.pushLevel(0.7)
        for _ in 0..<AppState.LEVEL_HISTORY_COUNT { state.pushLevel(0.1) }

        state.transition(to: .transcribing)

        XCTAssertEqual(state.recordingPeakLevel, 0.7)
    }

    func testNewRecordingStartsWithZeroPeak() {
        let state = AppState()
        state.transition(to: .recording)
        state.pushLevel(0.7)
        state.transition(to: .idle)

        state.transition(to: .recording)

        XCTAssertEqual(state.recordingPeakLevel, 0)
    }

    func testTransientPhaseReturnsToIdle() async throws {
        let state = AppState()

        state.transition(to: .inserted, resetAfter: 0.05)
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(state.phase, .idle)
    }

    func testNewPhaseCancelsPendingReset() async throws {
        let state = AppState()

        state.transition(to: .inserted, resetAfter: 0.05)
        state.transition(to: .recording)
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(state.phase, .recording)
    }
}
