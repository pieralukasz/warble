import SwiftUI

enum MainSection: String, CaseIterable, Identifiable, Hashable {
    case history
    case dictionary
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "History"
        case .dictionary: return "Dictionary"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .history: return "clock.arrow.circlepath"
        case .dictionary: return "character.book.closed"
        case .settings: return "gearshape"
        }
    }
}

/// Which section the main window shows; set from the menu bar too.
@MainActor
@Observable
final class MainNavigation {
    var section: MainSection = .history
}

/// The library window: a system sidebar with plain content, like System Settings.
struct MainView: View {
    @Environment(MainNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            List(MainSection.allCases, selection: $navigation.section) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .safeAreaInset(edge: .bottom) {
                SidebarStatus()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        } detail: {
            switch navigation.section {
            case .history: HistoryView()
            case .dictionary: DictionaryView()
            case .settings: SettingsView()
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

/// One quiet line under the sidebar saying whether dictation works right now.
private struct SidebarStatus: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DictationStatus.color(for: appState))
                .frame(width: 7, height: 7)
            Text(DictationStatus.text(for: appState))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

/// Shared wording and color for the current state, used by the sidebar and the menu bar panel.
@MainActor
enum DictationStatus {
    static func text(for appState: AppState) -> String {
        switch appState.model {
        case .loading(let fraction, _):
            return fraction.map { "Downloading model · \(Int($0 * 100))%" } ?? "Loading model…"
        case .failed:
            return "Model unavailable"
        default:
            return appState.phase.statusText
        }
    }

    static func color(for appState: AppState) -> Color {
        if case .failed = appState.model { return .red }
        guard appState.model.isReady else { return .orange }
        switch appState.phase {
        case .idle, .inserted, .copied: return .green
        case .recording: return .red
        case .transcribing, .preparing: return .orange
        case .needsAccessibility, .error: return .yellow
        }
    }
}
