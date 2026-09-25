import SwiftUI

struct SettingsView: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.appActions) private var actions

    /// Choices for how many recordings to keep; 0 means audio is deleted after transcription.
    static let RECORDING_LIMITS = [0, 10, 25, 50, 100]

    var body: some View {
        Form {
            dictationSection
            feedbackSection
            AudioSettingsSection()
            PrivacySettingsSection()
            SystemSettingsSection()
            AboutSection()
            if let error = settings.saveError {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private var dictationSection: some View {
        Section("Dictation") {
            LabeledContent("Hotkey") {
                HotkeyRecorder(
                    hotkey: settings.config.hotkey,
                    onChange: { hotkey in settings.update { $0.hotkey = hotkey } },
                    onRecordingChange: actions.pauseHotkeys
                )
            }
            Picker("Mode", selection: binding(\.isToggleMode) { config, isToggle in
                config.toggleMode = FlexBool(isToggle)
            }) {
                Text("Hold to talk").tag(false)
                Text("Press to start, press to stop").tag(true)
            }
            Picker("Language", selection: binding(\.config.language) { $0.language = $1 }) {
                ForEach(Config.supportedLanguages, id: \.code) { language in
                    Text(language.name).tag(language.code)
                }
            }
            Toggle(isOn: binding(\.usesSpokenPunctuation) { $0.spokenPunctuation = FlexBool($1) }) {
                Text("Spoken punctuation")
                Text("Say “comma”, “period” or “new line” to insert them.")
            }
        }
    }

    private var feedbackSection: some View {
        Section("Feedback") {
            Toggle(isOn: binding(\.showsPill) { $0.shouldShowRecordingPill = FlexBool($1) }) {
                Text("Show recording pill")
                Text("A small waveform near the bottom of the screen while you speak.")
            }
            Toggle("Play sounds", isOn: binding(\.playsSounds) { $0.shouldPlaySounds = FlexBool($1) })
        }
    }

    /// A binding that reads from the settings model and writes through `update`.
    private func binding<Value>(
        _ read: KeyPath<SettingsModel, Value>,
        write: @escaping (inout Config, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: read] },
            set: { newValue in settings.update { write(&$0, newValue) } }
        )
    }
}

private struct AudioSettingsSection: View {
    @Environment(SettingsModel.self) private var settings
    @State private var devices = AudioDeviceManager.listInputDevices()

    var body: some View {
        Section("Audio") {
            Picker("Listen to", selection: Binding(
                get: { settings.config.audioCaptureSource },
                set: { source in settings.update { $0.audioCaptureSource = source } }
            )) {
                ForEach(AudioCaptureSource.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Microphone", selection: Binding(
                get: { settings.config.audioInputDeviceUID ?? "" },
                set: { uid in select(uid) }
            )) {
                Text("System Default").tag("")
                ForEach(devices, id: \.name) { device in
                    Text(device.name).tag(device.uid ?? "")
                }
            }
            .disabled(!settings.config.audioCaptureSource.includesMicrophone)
        }
        .onAppear { devices = AudioDeviceManager.listInputDevices() }
    }

    private func select(_ uid: String) {
        let device = devices.first { $0.uid == uid }
        settings.update {
            $0.audioInputDeviceUID = device?.uid
            $0.audioInputDeviceID = device?.id
        }
    }
}
