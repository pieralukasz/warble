import Foundation

/// Believable sample content for preview screenshots.
enum PreviewData {
    struct Sample {
        let minutesAgo: Double
        let text: String
        let seconds: Double
        let app: String
        let bundleID: String
    }

    static let samples: [Sample] = [
        Sample(minutesAgo: 4, text: "Can we move the design review to Thursday afternoon? I want the new onboarding flow in front of everyone before we lock the release.", seconds: 9, app: "Mail", bundleID: "com.apple.mail"),
        Sample(minutesAgo: 22, text: "Refactor the recorder so the level meter runs on the audio thread and only publishes to the main actor.", seconds: 7, app: "Xcode", bundleID: "com.apple.dt.Xcode"),
        Sample(minutesAgo: 47, text: "Groceries: oat milk, blueberries, sourdough, two lemons and coffee beans.", seconds: 5, app: "Notes", bundleID: "com.apple.Notes"),
        Sample(minutesAgo: 95, text: "Thanks for the quick turnaround. The Kubernetes migration looks good to me, ship it.", seconds: 6, app: "Messages", bundleID: "com.apple.MobileSMS"),
        Sample(minutesAgo: 1_500, text: "Draft for the blog: local speech recognition finally feels instant, and nothing has to leave your laptop.", seconds: 8, app: "Safari", bundleID: "com.apple.Safari"),
        Sample(minutesAgo: 1_560, text: "Remind me to book the dentist and renew the car insurance before Friday.", seconds: 4, app: "Reminders", bundleID: "com.apple.reminders"),
        Sample(minutesAgo: 1_640, text: "Summary of today's standup: API is done, the pill animation needs polish, docs site goes live next week.", seconds: 10, app: "Notes", bundleID: "com.apple.Notes"),
    ]

    static let dictionary: [DictionaryEntry] = [
        .word("Kubernetes"),
        .word("SwiftUI"),
        .word("Parakeet"),
        .word("GitHub"),
        .replacement("my email", with: "hello@example.com"),
        .replacement("my sign off", with: "Best,\nAlex"),
        .replacement("office address", with: "221B Baker Street, London"),
    ]

    /// Fresh files in the preview folder, so each launch starts from the same state.
    static func seed(now: Date = Date()) throws -> (history: URL, dictionary: URL) {
        let folder = PreviewMode.dataDirectory
        try? FileManager.default.removeItem(at: folder)
        let historyURL = folder.appendingPathComponent("history.json")
        let dictionaryURL = folder.appendingPathComponent("dictionary.json")

        let entries = samples.map { sample in
            HistoryEntry(
                date: now.addingTimeInterval(-sample.minutesAgo * 60),
                text: sample.text,
                durationSeconds: sample.seconds,
                appName: sample.app,
                appBundleID: sample.bundleID
            )
        }
        try JSONFileStore<[HistoryEntry]>(fileURL: historyURL).save(entries)
        try JSONFileStore<[DictionaryEntry]>(fileURL: dictionaryURL).save(dictionary)
        return (historyURL, dictionaryURL)
    }
}
