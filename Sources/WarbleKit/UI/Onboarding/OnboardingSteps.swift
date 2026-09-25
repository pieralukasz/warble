import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text("Welcome to Warble")
                .font(.system(size: 34, weight: .bold))
            Text("Hold a key, speak, let go. Your words appear wherever you type.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                feature("lock.shield", "Private by design", "Parakeet runs on your Mac. Audio never leaves it.")
                feature("gift", "Free for good", "No account, no subscription, no word limits.")
                feature("app.badge.checkmark", "Works everywhere", "Mail, Slack, your editor, any text field.")
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}

struct MicrophoneStep: View {
    let status: PermissionStatus.Microphone
    let refresh: () -> Void

    var body: some View {
        StepLayout(
            symbol: "mic.fill",
            title: "Let Warble hear you",
            message: "The microphone is only on while you hold the dictation key."
        ) {
            switch status {
            case .granted:
                GrantedBadge(text: "Microphone allowed")
            case .notDetermined:
                Button("Allow Microphone") {
                    Task {
                        _ = await PermissionStatus.requestMicrophone()
                        refresh()
                    }
                }
                .buttonStyle(.glassProminent)
            case .denied:
                VStack(spacing: 10) {
                    Text("Access was turned off earlier. Switch Warble on in System Settings.")
                        .foregroundStyle(.secondary)
                    Button("Open Microphone Settings") { PermissionStatus.openMicrophoneSettings() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }
}

struct AccessibilityStep: View {
    let isGranted: Bool

    var body: some View {
        StepLayout(
            symbol: "keyboard.fill",
            title: "Let Warble type for you",
            message: "Accessibility access lets Warble notice your hotkey and paste text into the app you are using."
        ) {
            if isGranted {
                GrantedBadge(text: "Accessibility allowed")
            } else {
                VStack(spacing: 10) {
                    Button("Open Accessibility Settings") {
                        Permissions.promptAccessibility()
                        Permissions.openAccessibilitySettings()
                    }
                    .buttonStyle(.glassProminent)
                    Text("Turn on Warble in the list. This screen continues by itself.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ModelStep: View {
    @Environment(AppState.self) private var appState
    @Environment(\.appActions) private var actions

    var body: some View {
        StepLayout(
            symbol: "cpu",
            title: "Download the speech model",
            message: "Parakeet TDT v3 is downloaded once, then works offline in \(Config.supportedLanguages.count - 1) languages."
        ) {
            switch appState.model {
            case .ready:
                GrantedBadge(text: "Parakeet v3 is ready")
            case .failed(let message):
                VStack(spacing: 10) {
                    Text(message).foregroundStyle(.secondary)
                    Button("Try Again", action: actions.retryModel).buttonStyle(.glassProminent)
                }
            case .loading(let fraction, let detail):
                VStack(spacing: 8) {
                    if let fraction {
                        ProgressView(value: fraction)
                    } else {
                        ProgressView()
                    }
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 360)
            case .notLoaded:
                ProgressView()
            }
        }
    }
}

struct ShortcutStep: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.appActions) private var actions

    var body: some View {
        StepLayout(
            symbol: "globe",
            title: "Pick your key",
            message: "Hold it to talk. The fn 🌐 key works well on Mac keyboards; Right Option is a good second choice."
        ) {
            Form {
                LabeledContent("Hotkey") {
                    HotkeyRecorder(
                        hotkey: settings.config.hotkey,
                        onChange: { hotkey in settings.update { $0.hotkey = hotkey } },
                        onRecordingChange: actions.pauseHotkeys
                    )
                }
                Picker("Language", selection: Binding(
                    get: { settings.config.language },
                    set: { code in settings.update { $0.language = code } }
                )) {
                    ForEach(Config.supportedLanguages, id: \.code) { Text($0.name).tag($0.code) }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(maxWidth: 420, maxHeight: 150)
        }
    }
}

struct TryItStep: View {
    @Environment(AppState.self) private var appState
    @Environment(HistoryStore.self) private var history
    @State private var text = ""
    @State private var startCount: Int?
    @FocusState private var isFocused: Bool

    var body: some View {
        StepLayout(
            symbol: "waveform",
            title: didDictate ? "That’s all there is to it" : "Give it a try",
            message: "Click the box, hold \(appState.hotkeySummary) and say something. Let go to see it typed."
        ) {
            TextEditor(text: $text)
                .font(.title3)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(maxWidth: 460, minHeight: 110, maxHeight: 130)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .onAppear {
            startCount = history.entries.count
            isFocused = true
        }
    }

    private var didDictate: Bool {
        guard let startCount else { return false }
        return history.entries.count > startCount
    }
}

private struct GrantedBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }
}
