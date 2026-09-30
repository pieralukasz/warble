import AppKit
import SwiftUI

/// Hosts the pill in a panel above every app, on every Space. Only the pill
/// itself takes clicks: it can be dragged anywhere and closed.
@MainActor
final class RecordingPillController {
    static let PANEL_SIZE = NSSize(width: 360, height: 72)
    /// Gap between the pill and the Dock or the bottom of the screen.
    static let BOTTOM_MARGIN: CGFloat = 12
    /// Long enough for the SwiftUI exit transition to finish before the panel goes away.
    static let HIDE_DELAY: Duration = .milliseconds(450)

    private let appState: AppState
    let panel: NSPanel
    private let mover: MovablePill
    private var hideTask: Task<Void, Never>?

    var isEnabled = true {
        didSet { update() }
    }

    init(appState: AppState) {
        self.appState = appState
        panel = Self.makePanel()
        mover = MovablePill(
            panel: panel,
            defaultBottom: Self.BOTTOM_MARGIN,
            defaults: PreviewMode.isActive ? nil : .standard
        )
        let host = PillHostingView(rootView: RecordingPillView(mover: mover).environment(appState))
        host.frame = NSRect(origin: .zero, size: Self.PANEL_SIZE)
        panel.contentView = host
        mover.onDismiss = { [weak self] in self?.update() }

        observeContinuously({ [weak self] in
            _ = self?.appState.phase
        }, onChange: { [weak self] in
            self?.update()
        })
    }

    private var shouldShow: Bool {
        isEnabled && !mover.isDismissed && PillContent(phase: appState.phase) != nil
    }

    private func update() {
        hideTask?.cancel()
        // A closed pill comes back with the next dictation, or to show a problem.
        switch PillContent(phase: appState.phase) {
        case nil, .failed: mover.clearDismissal()
        default: break
        }
        guard shouldShow else {
            hideTask = Task { [panel, mover] in
                try? await Task.sleep(for: Self.HIDE_DELAY)
                guard !Task.isCancelled else { return }
                panel.orderOut(nil)
                mover.didHide()
            }
            return
        }
        if !panel.isVisible {
            // Follows the pointer to the screen the user is working on.
            mover.place()
            panel.orderFrontRegardless()
        }
        mover.didShow()
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
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }
}
