import Foundation

/// A press too short to record anything. In hold mode it is almost always a tap
/// by someone expecting toggle mode, and dropping it without a word made Warble
/// look like it ignored the key.
enum ShortPress {
    /// What the pill says after a tap, or nil in toggle mode, where a tap is how
    /// recording starts. Shortcuts such as Right ⌘ C never get here: they are
    /// cancelled on release.
    static func hint(toggleMode: Bool, hotkeys: [HotkeyConfig]) -> String? {
        guard !toggleMode else { return nil }
        return "Hold \(HotkeyLabel.describe(hotkeys)) to dictate"
    }
}
