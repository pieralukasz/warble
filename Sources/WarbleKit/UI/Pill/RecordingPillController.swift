import AppKit
import SwiftUI

/// Hosts the pill in a click-through panel above every app, on every Space.
@MainActor
final class RecordingPillController {
    static let PANEL_SIZE = NSSize(width: 360, height: 72)
    /// Gap between the pill and the Dock or the bottom of the screen.
    static let BOTTOM_MARGIN: CGFloat = 12
    /// Long enough for the SwiftUI exit transition to finish before the panel goes away.
    static let HIDE_DELAY: Duration = .milliseconds(450)

    private let appState: AppState
    let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    var isEnabled = true {
        didSet { update() }
    }

    init(appState: AppState) {
        self.appState = appState
        panel = Self.makePanel()
        let host = NSHostingView(rootView: RecordingPillView().environment(appState))
        host.frame = NSRect(origin: .zero, size: Self.PANEL_SIZE)
        panel.contentView = host

        observeContinuously({ [weak self] in
            _ = self?.appState.phase
        }, onChange: { [weak self] in
            self?.update()
        })
    }

    private var shouldShow: Bool {
        isEnabled && PillContent(phase: appState.phase) != nil
    }

    private func update() {
        hideTask?.cancel()
        guard shouldShow else {
            hideTask = Task { [panel] in
                try? await Task.sleep(for: Self.HIDE_DELAY)
                guard !Task.isCancelled else { return }
                panel.orderOut(nil)
            }
            return
        }
        if !panel.isVisible {
            position()
            panel.orderFrontRegardless()
        }
    }

    /// Follows the pointer to the screen the user is working on.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: visible.midX - Self.PANEL_SIZE.width / 2,
            y: visible.minY + Self.BOTTOM_MARGIN
        )
        panel.setFrame(NSRect(origin: origin, size: Self.PANEL_SIZE), display: false)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: PANEL_SIZE),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }
}
