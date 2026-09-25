import SwiftUI

enum MainSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case history
    case dictionary
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .history: return "History"
        case .dictionary: return "Dictionary"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
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
    var section: MainSection = .home
}

struct MainView: View {
    @Environment(MainNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            List(MainSection.allCases, selection: $navigation.section) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) {
                SidebarStatus()
                    .padding(12)
            }
        } detail: {
            detail(for: navigation.section)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .tint(Theme.accent)
        .frame(minWidth: 780, minHeight: 540)
    }

    @ViewBuilder
    private func detail(for section: MainSection) -> some View {
        switch section {
        case .home: HomeView()
        case .history: HistoryView()
        case .dictionary: DictionaryView()
        case .settings: SettingsView()
        }
    }
}

/// A compact line at the bottom of the sidebar that says whether dictation works right now.
private struct SidebarStatus: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }

    private var text: String {
        if case .loading = appState.model { return "Loading model…" }
        if case .failed = appState.model { return "Model unavailable" }
        return appState.phase.statusText
    }

    private var color: Color {
        switch appState.phase {
        case .idle, .inserted, .copied: return appState.model.isReady ? Theme.accent : .orange
        case .recording: return .red
        case .transcribing, .preparing: return .orange
        case .needsAccessibility, .error: return .yellow
        }
    }
}
