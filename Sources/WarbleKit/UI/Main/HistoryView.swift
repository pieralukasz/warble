import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @State private var query = ""
    @State private var isConfirmingClear = false

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "waveform",
                    description: Text("Everything you dictate shows up here, searchable and private.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                list
            }
        }
        .navigationTitle("History")
        .searchable(text: $query, placement: .toolbar, prompt: "Search dictations")
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

    private var results: [HistoryEntry] { history.search(query) }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedByDay, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { HistoryRow(entry: $0) }
                    } header: {
                        Text(Self.title(for: group.day))
                            .font(.headline)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
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
