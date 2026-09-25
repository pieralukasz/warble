import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(HistoryStore.self) private var history
    @Environment(MainNavigation.self) private var navigation
    @Environment(\.appActions) private var actions

    static let RECENT_COUNT = 4

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: greeting, subtitle: "Your voice, typed. Nothing leaves this Mac.")
                HeroCard()
                statsRow
                recent
            }
            .padding(Theme.pagePadding)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var statsRow: some View {
        let stats = history.stats
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
            StatTile(title: "Words today", value: stats.wordsToday.formatted(), symbol: "sun.max")
            StatTile(title: "Words dictated", value: stats.totalWords.formatted(), symbol: "text.word.spacing")
            StatTile(title: "Words per minute", value: stats.wordsPerMinute.formatted(), symbol: "speedometer")
            StatTile(title: "Minutes saved", value: stats.minutesSaved.formatted(), symbol: "hourglass")
        }
    }

    @ViewBuilder
    private var recent: some View {
        if !history.entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent").font(.title2.weight(.semibold))
                    Spacer()
                    Button("See All") { navigation.section = .history }
                        .buttonStyle(.glass)
                }
                ForEach(history.entries.prefix(Self.RECENT_COUNT)) { entry in
                    HistoryRow(entry: entry)
                }
            }
        }
    }
}

/// The main call to action: how to dictate, or what is still missing before you can.
private struct HeroCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.appActions) private var actions

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle().fill(Theme.brandGradient)
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: appState.phase == .recording)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.title2.weight(.semibold))
                    Text(detail).foregroundStyle(.secondary)
                    extra
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var symbol: String {
        switch appState.model {
        case .loading: return "arrow.down.circle"
        case .failed: return "exclamationmark.triangle"
        default: return appState.phase == .needsAccessibility ? "lock" : "waveform"
        }
    }

    private var title: String {
        switch appState.model {
        case .loading: return "Getting Parakeet ready"
        case .failed: return "The speech model could not load"
        default:
            if appState.phase == .needsAccessibility { return "One permission left" }
            return "Hold \(appState.hotkeySummary) and speak"
        }
    }

    private var detail: String {
        switch appState.model {
        case .loading(_, let detail): return detail
        case .failed(let message): return message
        default:
            if appState.phase == .needsAccessibility {
                return "Warble needs Accessibility access to type into other apps."
            }
            return "Let go and your words appear at the cursor, in any app."
        }
    }

    @ViewBuilder
    private var extra: some View {
        switch appState.model {
        case .loading(let fraction, _):
            if let fraction {
                ProgressView(value: fraction).frame(maxWidth: 320)
            } else {
                ProgressView().controlSize(.small)
            }
        case .failed:
            Button("Try Again", action: actions.retryModel).buttonStyle(.glassProminent)
        default:
            if appState.phase == .needsAccessibility {
                Button("Open Accessibility Settings") { Permissions.openAccessibilitySettings() }
                    .buttonStyle(.glassProminent)
            }
        }
    }
}
