import SwiftUI

/// Every dictation in a plain, searchable list grouped by day.
struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @State private var query = ""
    @State private var selection: HistoryEntry.ID?
    @State private var isConfirmingClear = false

    var body: some View {
        content
            .navigationTitle("History")
            .navigationSubtitle(subtitle)
            .searchable(text: $query, placement: .toolbar, prompt: "Search")
            .toolbar {
                ToolbarItem {
                    Button("Clear History", systemImage: "trash") { isConfirmingClear = true }
                        .disabled(history.entries.isEmpty)
                }
            }
            .confirmationDialog("Delete all dictations?", isPresented: $isConfirmingClear) {
                Button("Delete All", role: .destructive) { history.removeAll() }
            } message: {
                Text("The text of every dictation is removed from this Mac. Saved audio files stay in the recordings folder.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if history.entries.isEmpty {
            ContentUnavailableView {
                Label("No Dictations Yet", systemImage: "waveform")
            } description: {
                Text("Hold your dictation key and start talking. Everything you say shows up here.")
            }
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(selection: $selection) {
                ForEach(groupedByDay, id: \.day) { group in
                    Section(Self.title(for: group.day)) {
                        ForEach(group.entries) { HistoryRow(entry: $0) }
                    }
                }
            }
            .listStyle(.inset)
            .alternatingRowBackgrounds(.disabled)
        }
    }

    private var results: [HistoryEntry] { history.search(query) }

    private var subtitle: String {
        let stats = history.stats
        guard stats.dictationCount > 0 else { return "" }
        return "\(stats.totalWords.formatted()) words · \(stats.wordsPerMinute) wpm · \(stats.minutesSaved) min saved"
    }

    private var groupedByDay: [(day: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: results) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .complete, time: .omitted)
    }
}
