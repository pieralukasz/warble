import SwiftUI

/// Words and replacements in a plain list, with a floating glass bar for adding more.
struct DictionaryView: View {
    @Environment(DictionaryStore.self) private var dictionary

    var body: some View {
        list
            .navigationTitle("Dictionary")
            .navigationSubtitle("Fixed after every dictation, on this Mac")
            .safeAreaInset(edge: .bottom) {
                AddEntryBar()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
    }

    @ViewBuilder
    private var list: some View {
        if dictionary.entries.isEmpty {
            ContentUnavailableView {
                Label("Teach Warble Your Words", systemImage: "character.book.closed")
            } description: {
                Text("Add names and jargon so they are always spelled right, or short phrases that expand into longer text.")
            }
        } else {
            List {
                if !dictionary.words.isEmpty {
                    Section("Words") {
                        ForEach(dictionary.words) { WordRow(entry: $0) }
                    }
                }
                if !dictionary.replacements.isEmpty {
                    Section("Replacements") {
                        ForEach(dictionary.replacements) { WordRow(entry: $0) }
                    }
                }
                if let problem = dictionary.loadWarning ?? dictionary.saveError {
                    Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct WordRow: View {
    let entry: DictionaryEntry
    @Environment(DictionaryStore.self) private var dictionary
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            if entry.kind == .replacement {
                Text(entry.spoken).foregroundStyle(.secondary)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
            }
            // Multi-line expansions show on one line, with a return symbol per break.
            Text(entry.written.replacingOccurrences(of: "\n", with: " ⏎ ")).lineLimit(1)
            Spacer()
            Button("Remove", systemImage: "minus.circle.fill") { dictionary.remove(id: entry.id) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .opacity(isHovering ? 1 : 0)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Remove", role: .destructive) { dictionary.remove(id: entry.id) }
        }
    }
}

/// The floating bar at the bottom: pick a kind, type, press Return.
private struct AddEntryBar: View {
    @Environment(DictionaryStore.self) private var dictionary
    @State private var kind: DictionaryEntry.Kind = .word
    @State private var spoken = ""
    @State private var written = ""
    @FocusState private var isSpokenFocused: Bool

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 10) {
                Picker("Kind", selection: $kind) {
                    Image(systemName: "textformat").tag(DictionaryEntry.Kind.word).help("Word")
                    Image(systemName: "arrow.2.squarepath").tag(DictionaryEntry.Kind.replacement).help("Replacement")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                TextField(kind == .word ? "Add a word or name" : "When I say…", text: $spoken)
                    .focused($isSpokenFocused)
                    .onSubmit(add)
                if kind == .replacement {
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("…type this", text: $written).onSubmit(add)
                }

                Button("Add", systemImage: "plus", action: add)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .disabled(!canAdd)
            }
            .textFieldStyle(.plain)
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .frame(maxWidth: 560)
        .animation(.smooth, value: kind)
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
