import AppKit
import SwiftUI

/// Captures the next key press as the dictation hotkey. Modifier-only keys
/// such as fn or Right Option count on their own; Esc cancels.
struct HotkeyRecorder: View {
    let hotkey: HotkeyConfig
    let onChange: (HotkeyConfig) -> Void
    /// Global hotkeys are paused while recording so the press does not start dictation.
    let onRecordingChange: (Bool) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    private static let ESCAPE_KEY_CODE: UInt16 = 53
    private static let modifierOnlyKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62, 63]

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: isRecording ? "record.circle" : "keyboard")
                    .symbolEffect(.pulse, isActive: isRecording)
                Text(isRecording ? "Press a key…" : HotkeyLabel.describe(hotkey))
                    .monospaced()
            }
            .frame(minWidth: 150)
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? .accentColor : nil)
        .onDisappear(perform: stopRecording)
        .help("Click, then press the key you want to hold while dictating")
    }

    private func toggle() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        onRecordingChange(false)
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == Self.ESCAPE_KEY_CODE {
            stopRecording()
            return
        }
        if event.type == .flagsChanged {
            // Only the press of a modifier counts, not its release.
            guard Self.modifierOnlyKeyCodes.contains(event.keyCode), isModifierDown(event) else { return }
            finish(HotkeyConfig(keyCode: event.keyCode, modifiers: []))
            return
        }
        finish(HotkeyConfig(keyCode: event.keyCode, modifiers: modifierNames(event.modifierFlags)))
    }

    private func finish(_ hotkey: HotkeyConfig) {
        stopRecording()
        onChange(hotkey)
    }

    private func isModifierDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        switch event.keyCode {
        case 63: return flags.contains(.function)
        case 54, 55: return flags.contains(.command)
        case 56, 60: return flags.contains(.shift)
        case 58, 61: return flags.contains(.option)
        case 59, 62: return flags.contains(.control)
        default: return false
        }
    }

    private func modifierNames(_ flags: NSEvent.ModifierFlags) -> [String] {
        var names: [String] = []
        if flags.contains(.control) { names.append("ctrl") }
        if flags.contains(.option) { names.append("option") }
        if flags.contains(.shift) { names.append("shift") }
        if flags.contains(.command) { names.append("cmd") }
        return names
    }
}
