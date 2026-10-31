import XCTest
@testable import WarbleKit

final class ShortPressTests: XCTestCase {
    private let rightCommand = [HotkeyConfig(keyCode: 54, modifiers: [])]

    func testTapInHoldModeTellsToHoldTheKey() {
        let hint = ShortPress.hint(toggleMode: false, hotkeys: rightCommand)

        XCTAssertEqual(hint, "Hold Right ⌘ to dictate")
    }

    func testToggleModeNeedsNoHint() {
        let hint = ShortPress.hint(toggleMode: true, hotkeys: rightCommand)

        XCTAssertNil(hint)
    }
}

final class ModifierHotkeyStateTests: XCTestCase {
    func testPressAndReleaseOfTheModifierAloneIsNotAChord() {
        var state = ModifierHotkeyState(keyCode: 54)

        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .pressed)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .released(wasChord: false))
    }

    func testAnotherKeyWhileHeldMakesItAChord() {
        var state = ModifierHotkeyState(keyCode: 54)

        _ = state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true)
        XCTAssertEqual(state.handle(.keyDown, modifiersSatisfied: true), .none)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .released(wasChord: true))
    }

    func testAnotherModifierWhileHeldMakesItAChord() {
        var state = ModifierHotkeyState(keyCode: 54)

        _ = state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 56), modifiersSatisfied: true), .none)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .released(wasChord: true))
    }

    func testChordDoesNotCarryOverToTheNextPress() {
        var state = ModifierHotkeyState(keyCode: 54)

        _ = state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true)
        _ = state.handle(.keyDown, modifiersSatisfied: true)
        _ = state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true)

        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .pressed)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .released(wasChord: false))
    }

    func testKeysWhileNotHeldAreIgnored() {
        var state = ModifierHotkeyState(keyCode: 54)

        XCTAssertEqual(state.handle(.keyDown, modifiersSatisfied: true), .none)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 56), modifiersSatisfied: true), .none)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .pressed)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .released(wasChord: false))
    }

    func testMissingRequiredModifiersDoNotPress() {
        var state = ModifierHotkeyState(keyCode: 54)

        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: false), .none)
        XCTAssertEqual(state.handle(.flagsChanged(keyCode: 54), modifiersSatisfied: true), .pressed)
    }
}
