import Foundation

/// Readable names for hotkeys, e.g. "⌃ Space" instead of "ctrl+space".
public enum HotkeyLabel {
    private static let modifierSymbols: [String: String] = [
        "cmd": "⌘", "command": "⌘",
        "shift": "⇧",
        "ctrl": "⌃", "control": "⌃",
        "opt": "⌥", "option": "⌥", "alt": "⌥",
    ]

    private static let keyNames: [UInt16: String] = [
        63: "fn 🌐",
        54: "Right ⌘", 55: "Left ⌘",
        56: "Left ⇧", 60: "Right ⇧",
        58: "Left ⌥", 61: "Right ⌥",
        59: "Left ⌃", 62: "Right ⌃",
        57: "Caps Lock",
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc",
    ]

    public static func describe(_ hotkey: HotkeyConfig) -> String {
        let modifiers = hotkey.modifiers.compactMap { modifierSymbols[$0.lowercased()] }
        let key = keyNames[hotkey.keyCode]
            ?? KeyCodes.codeToName[hotkey.keyCode]?.uppercased()
            ?? "Key \(hotkey.keyCode)"
        return (modifiers + [key]).joined(separator: " ")
    }

    public static func describe(_ hotkeys: [HotkeyConfig]) -> String {
        hotkeys.map(describe).joined(separator: " or ")
    }
}
