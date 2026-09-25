import SwiftUI

struct PrivacySettingsSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(HistoryStore.self) private var history
    @State private var isConfirmingClear = false

    var body: some View {
        Section {
            Picker("Keep audio recordings", selection: Binding(
                get: { settings.keptRecordings },
                set: { count in settings.update { $0.maxRecordings = count } }
            )) {
                ForEach(SettingsView.RECORDING_LIMITS, id: \.self) { count in
                    Text(count == 0 ? "Never" : "Last \(count)").tag(count)
                }
            }
            LabeledContent("History") {
                HStack {
                    Text("\(history.entries.count) dictations").foregroundStyle(.secondary)
                    Button("Clear…") { isConfirmingClear = true }
                        .disabled(history.entries.isEmpty)
                }
            }
            LabeledContent("Data folder") {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppDirectories.applicationSupport])
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Audio, text and the speech model stay on this Mac. Warble has no account, no analytics and no network calls after the model download.")
        }
        .confirmationDialog("Delete all dictations?", isPresented: $isConfirmingClear) {
            Button("Delete All", role: .destructive) { history.removeAll() }
        }
    }
}

struct SystemSettingsSection: View {
    @Environment(\.appActions) private var actions
    @State private var startsAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Section("System") {
            Toggle("Start Warble at login", isOn: Binding(
                get: { startsAtLogin },
                set: { startsAtLogin = actions.setLaunchAtLogin($0) }
            ))
            LabeledContent("Permissions and setup") {
                Button("Run Setup Again", action: actions.openOnboarding)
            }
        }
    }
}

struct AboutSection: View {
    @Environment(AppState.self) private var appState

    static let repositoryURL = URL(string: "https://github.com/pieralukasz/warble")!

    var body: some View {
        Section("About") {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Warble \(AppInfo.version)").font(.headline)
                    Text("Parakeet TDT v3 · on-device · \(modelLine)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Link("GitHub", destination: Self.repositoryURL)
            }
            Text("Free and open source under the MIT License. Built on FluidAudio and NVIDIA Parakeet, and grown from open-wispr by human37.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modelLine: String {
        switch appState.model {
        case .ready: return "loaded"
        case .loading: return "loading"
        case .failed: return "failed to load"
        case .notLoaded: return "not loaded"
        }
    }
}
