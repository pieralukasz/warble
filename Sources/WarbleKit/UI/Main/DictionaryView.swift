import SwiftUI

struct DictionaryView: View {
    @Environment(DictionaryStore.self) private var dictionary
    @State private var kind: DictionaryEntry.Kind = .word
    @State private var spoken = ""
    @State private var written = ""
    @FocusState private var isSpokenFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Dictionary",
                    subtitle: "Teach Warble your names, jargon and shortcuts."
                )
                Picker("Kind", selection: $kind) {
                    Text("Words").tag(DictionaryEntry.Kind.word)
                    Text("Replacements").tag(DictionaryEntry.Kind.replacement)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)

                addCard
                entriesList
                if let problem = dictionary.loadWarning ?? dictionary.saveError {
                    Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            }
            .padding(Theme.pagePadding)
        }
        .navigationTitle("Dictionary")
    }

    private var addCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(explanation).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    TextField(kind == .word ? "Word or name, e.g. Kubernetes" : "When I say…", text: $spoken)
                        .focused($isSpokenFocused)
                        .onSubmit(add)
                    if kind == .replacement {
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        TextField("…type this", text: $written).onSubmit(add)
                    }
                    Button("Add", action: add)
                        .buttonStyle(.glassProminent)
                        .disabled(!canAdd)
                        .keyboardShortcut(.defaultAction)
                }
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var explanation: String {
        kind == .word
            ? "Warble fixes the spelling and capitals of these words after every dictation."
            : "Say a short phrase and Warble types the full text, like an email address or a sign-off."
    }

    @ViewBuilder
    private var entriesList: some View {
        let entries = kind == .word ? dictionary.words : dictionary.replacements
        if entries.isEmpty {
            ContentUnavailableView(
                kind == .word ? "No words yet" : "No replacements yet",
                systemImage: kind == .word ? "character.book.closed" : "arrow.2.squarepath"
            )
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 8) {
                ForEach(entries) { entry in row(entry) }
            }
        }
    }

    private func row(_ entry: DictionaryEntry) -> some View {
        HStack {
            if entry.kind == .word {
                Text(entry.written).font(.body.weight(.medium))
            } else {
                Text("“\(entry.spoken)”").foregroundStyle(.secondary)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                Text(entry.written).font(.body.weight(.medium)).lineLimit(1)
            }
            Spacer()
            Button("Remove", systemImage: "xmark") { dictionary.remove(id: entry.id) }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private var canAdd: Bool {
        let hasSpoken = !spoken.trimmingCharacters(in: .whitespaces).isEmpty
        return kind == .word ? hasSpoken : hasSpoken && !written.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func add() {
        guard canAdd else { return }
        dictionary.add(kind == .word ? .word(spoken) : .replacement(spoken, with: written))
        spoken = ""
        written = ""
        isSpokenFocused = true
    }
}
