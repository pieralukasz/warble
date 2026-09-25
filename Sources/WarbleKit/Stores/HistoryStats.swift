import Foundation

/// Numbers for the Home screen, derived from the history on demand.
public struct HistoryStats: Equatable, Sendable {
    /// Typical typing speed used to estimate time saved; a common average for adults.
    static let TYPING_WORDS_PER_MINUTE = 40.0

    public var totalWords: Int
    public var wordsToday: Int
    public var dictationCount: Int
    public var wordsPerMinute: Int
    public var minutesSaved: Int

    public static func compute(
        from entries: [HistoryEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HistoryStats {
        let totalWords = entries.reduce(0) { $0 + $1.wordCount }
        let wordsToday = entries
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.wordCount }
        let spokenMinutes = entries.reduce(0) { $0 + $1.durationSeconds } / 60
        let wordsPerMinute = spokenMinutes > 0 ? Int((Double(totalWords) / spokenMinutes).rounded()) : 0
        let typingMinutes = Double(totalWords) / TYPING_WORDS_PER_MINUTE
        let minutesSaved = max(0, Int((typingMinutes - spokenMinutes).rounded()))

        return HistoryStats(
            totalWords: totalWords,
            wordsToday: wordsToday,
            dictationCount: entries.count,
            wordsPerMinute: wordsPerMinute,
            minutesSaved: minutesSaved
        )
    }
}
