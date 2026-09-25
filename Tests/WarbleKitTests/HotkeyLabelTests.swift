import XCTest
@testable import WarbleKit

final class HotkeyLabelTests: XCTestCase {
    func testGlobeKeyHasFriendlyName() {
        XCTAssertEqual(HotkeyLabel.describe(HotkeyConfig(keyCode: 63, modifiers: [])), "fn 🌐")
    }

    func testModifiersBecomeSymbolsBeforeTheKey() {
        let hotkey = HotkeyConfig(keyCode: 49, modifiers: ["ctrl", "shift"])

        XCTAssertEqual(HotkeyLabel.describe(hotkey), "⌃ ⇧ Space")
    }

    func testLetterKeysAreUppercased() {
        XCTAssertEqual(HotkeyLabel.describe(HotkeyConfig(keyCode: 2, modifiers: ["cmd"])), "⌘ D")
    }

    func testUnknownKeyCodeStillProducesALabel() {
        XCTAssertEqual(HotkeyLabel.describe(HotkeyConfig(keyCode: 200, modifiers: [])), "Key 200")
    }

    func testSeveralHotkeysAreJoined() {
        let hotkeys = [HotkeyConfig(keyCode: 63, modifiers: []), HotkeyConfig(keyCode: 61, modifiers: [])]

        XCTAssertEqual(HotkeyLabel.describe(hotkeys), "fn 🌐 or Right ⌥")
    }
}
