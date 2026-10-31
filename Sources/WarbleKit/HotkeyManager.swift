import AppKit
import Foundation

/// Press and release of a modifier-only hotkey such as Right ⌘. Both arrive as
/// flagsChanged events with the same key code; any other key in between means
/// the modifier was part of a shortcut, not a dictation.
struct ModifierHotkeyState {
    enum Event: Equatable {
        case keyDown
        case flagsChanged(keyCode: UInt16)
    }

    enum Output: Equatable {
        case none
        case pressed
        case released(wasChord: Bool)
    }

    let keyCode: UInt16
    private(set) var isPressed = false
    private var wasChord = false

    init(keyCode: UInt16) {
        self.keyCode = keyCode
    }

    /// `modifiersSatisfied` tells whether the hotkey's extra modifiers are down.
    mutating func handle(_ event: Event, modifiersSatisfied: Bool) -> Output {
        guard case .flagsChanged(let code) = event, code == keyCode else {
            if isPressed { wasChord = true }
            return .none
        }

        if isPressed {
            isPressed = false
            return .released(wasChord: wasChord)
        }
        guard modifiersSatisfied else { return .none }
        isPressed = true
        wasChord = false
        return .pressed
    }
}

class HotkeyManager {
    private var globalMonitor: Any?
    private let keyCode: UInt16
    private let requiredModifiers: UInt64
    private var onKeyDown: ((HotkeyKind) -> Void)?
    private var onKeyUp: ((HotkeyKind, _ wasChord: Bool) -> Void)?
    private var modifierState: ModifierHotkeyState

    init(keyCode: UInt16, modifiers: UInt64 = 0) {
        self.keyCode = keyCode
        self.requiredModifiers = modifiers
        self.modifierState = ModifierHotkeyState(keyCode: keyCode)
    }

    var kind: HotkeyKind { isModifierOnlyKey(keyCode) ? .modifier : .key }

    /// `onKeyUp` learns whether another key was pressed while a modifier hotkey was held.
    func start(
        onKeyDown: @escaping (HotkeyKind) -> Void,
        onKeyUp: @escaping (HotkeyKind, _ wasChord: Bool) -> Void
    ) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitor = nil
    }

    private func handleEvent(_ event: NSEvent) {
        if isModifierOnlyKey(keyCode) {
            let modifierEvent: ModifierHotkeyState.Event
            switch event.type {
            case .flagsChanged: modifierEvent = .flagsChanged(keyCode: event.keyCode)
            case .keyDown: modifierEvent = .keyDown
            default: return
            }
            switch modifierState.handle(modifierEvent, modifiersSatisfied: hasRequiredModifiers(event)) {
            case .pressed: onKeyDown?(.modifier)
            case .released(let wasChord): onKeyUp?(.modifier, wasChord)
            case .none: break
            }
        } else {
            guard event.keyCode == keyCode, hasRequiredModifiers(event) else { return }
            if event.type == .keyDown {
                onKeyDown?(.key)
            } else if event.type == .keyUp {
                onKeyUp?(.key, false)
            }
        }
    }

    private func hasRequiredModifiers(_ event: NSEvent) -> Bool {
        guard requiredModifiers != 0 else { return true }
        let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
        return currentMods & requiredModifiers == requiredModifiers
    }

    private func isModifierOnlyKey(_ code: UInt16) -> Bool {
        return [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(code)
    }
}
