import XCTest
@testable import WarbleKit

final class HistoryStatsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testEmptyHistoryProducesZeros() {
        let stats = HistoryStats.compute(from: [], now: now, calendar: calendar)

        XCTAssertEqual(stats, HistoryStats(totalWords: 0, wordsToday: 0, dictationCount: 0, wordsPerMinute: 0, minutesSaved: 0))
    }

    func testCountsWordsTodaySeparatelyFromTotal() {
        let yesterday = now.addingTimeInterval(-86_400)
        let entries = [
            HistoryEntry(date: now, text: "one two three", durationSeconds: 1),
            HistoryEntry(date: yesterday, text: "four five", durationSeconds: 1),
        ]

        let stats = HistoryStats.compute(from: entries, now: now, calendar: calendar)

        XCTAssertEqual(stats.totalWords, 5)
        XCTAssertEqual(stats.wordsToday, 3)
        XCTAssertEqual(stats.dictationCount, 2)
    }

    func testSpeakingRateAndTimeSavedAgainstTyping() {
        let text = Array(repeating: "word", count: 400).joined(separator: " ")
        let entries = [HistoryEntry(date: now, text: text, durationSeconds: 120)]

        let stats = HistoryStats.compute(from: entries, now: now, calendar: calendar)

        XCTAssertEqual(stats.wordsPerMinute, 200)
        XCTAssertEqual(stats.minutesSaved, 8)
    }
}
