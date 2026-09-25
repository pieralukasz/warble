import SwiftUI

/// What opens from the menu bar icon: status, the last dictation, quick
/// controls and the way into the library. The popover supplies the glass.
struct MenuBarPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(HistoryStore.self) private var history
    @Environment(\.appActions) private var actions

    static let WIDTH: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusHeader()
            if case .loading(let fraction, let detail) = appState.model {
                ModelProgress(fraction: fraction, detail: detail)
            }
            LastDictation()
            QuickControls()
            Divider()
            footer
        }
        .padding(16)
        .frame(width: Self.WIDTH)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("History") { actions.openMain(.history) }
            Button("Dictionary") { actions.openMain(.dictionary) }
            Spacer()
            Button("Settings", systemImage: "gearshape") { actions.openMain(.settings) }
                .labelStyle(.iconOnly)
                .help("Settings")
            Button("Quit Warble", systemImage: "power") { NSApp.terminate(nil) }
                .labelStyle(.iconOnly)
                .help("Quit Warble")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}

private struct StatusHeader: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.tint)
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: appState.phase == .recording)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(DictationStatus.text(for: appState))
                    .font(.headline)
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var symbol: String {
        switch appState.phase {
        case .recording: return "waveform"
        case .transcribing: return "ellipsis"
        case .inserted, .copied: return "checkmark"
        case .needsAccessibility: return "lock.fill"
        case .error: return "exclamationmark"
        case .idle, .preparing: return "waveform"
        }
    }

    private var hint: String {
        if appState.phase == .needsAccessibility { return "Allow Accessibility in System Settings" }
        return "Hold \(appState.hotkeySummary) to dictate"
    }
}

private struct ModelProgress: View {
    let fraction: Double?
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct LastDictation: View {
    @Environment(HistoryStore.self) private var history
    @State private var didCopy = false

    var body: some View {
        if let entry = history.entries.first {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.text)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    SourceAppIcon(bundleID: entry.appBundleID, size: 14)
                    Text(entry.date.formatted(.relative(presentation: .named)))
                    Text("·")
                    Text("\(history.stats.wordsToday.formatted()) words today")
                    Spacer()
                    Button("Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc") { copy(entry.text) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .contentTransition(.symbolEffect(.replace))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.fill.quaternary, in: .rect(cornerRadius: 12))
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}
