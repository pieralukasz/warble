import Foundation

/// Owns one global key monitor per configured hotkey.
@MainActor
final class HotkeyController {
    private var managers: [HotkeyManager] = []

    var isListening: Bool { !managers.isEmpty }

    func listen(to hotkeys: [HotkeyConfig], onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        stop()
        managers = hotkeys.map { hotkey in
            let manager = HotkeyManager(keyCode: hotkey.keyCode, modifiers: hotkey.modifierFlags)
            manager.start(onKeyDown: onKeyDown, onKeyUp: onKeyUp)
            return manager
        }
    }

    /// Stops listening, for example while the settings screen records a new hotkey.
    func stop() {
        managers.forEach { $0.stop() }
        managers = []
    }
}
