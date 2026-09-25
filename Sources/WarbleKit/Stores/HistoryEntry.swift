import Foundation

/// One finished dictation, kept so it can be found, copied or replayed later.
public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var text: String
    public var durationSeconds: Double
    /// File name inside the recordings folder, when the user keeps audio.
    public var audioFileName: String?
    public var appName: String?
    public var appBundleID: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String,
        durationSeconds: Double,
        audioFileName: String? = nil,
        appName: String? = nil,
        appBundleID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.durationSeconds = durationSeconds
        self.audioFileName = audioFileName
        self.appName = appName
        self.appBundleID = appBundleID
    }

    public var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
