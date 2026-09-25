import AppKit
import SwiftUI

/// The menu bar item. A click opens the glass panel; a right-click or
/// Control-click shows a short menu. The icon mirrors the dictation phase.
@MainActor
final class StatusBarController: NSObject {
    static let ANIMATION_FPS = 30.0

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appState: AppState
    private let popover = NSPopover()
    private let quickMenu = NSMenu()
    private var animationTimer: Timer?
    private var menuTargets: [MenuItemTarget] = []

    init(appState: AppState, panel: some View, openSettings: @escaping () -> Void) {
        self.appState = appState
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: panel)

        quickMenu.addItem(item("Settings…", key: ",", action: openSettings))
        quickMenu.addItem(.separator())
        quickMenu.addItem(NSMenuItem(title: "Quit Warble", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        if let button = statusItem.button {
            button.setAccessibilityLabel("Warble")
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()
        observeContinuously({ [weak self] in
            _ = self?.appState.phase
            _ = self?.appState.model
        }, onChange: { [weak self] in
            self?.updateIcon()
        })
    }

    /// Opens the panel, for the preview mode and for reopening the app from Finder.
    func showPanel() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    var panelWindow: NSWindow? { popover.contentViewController?.view.window }

    func closePanel() {
        popover.performClose(nil)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            closePanel()
            statusItem.menu = quickMenu
            sender.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func item(_ title: String, key: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = MenuItemTarget(handler: action)
        menuTargets.append(target)
        let item = NSMenuItem(title: title, action: #selector(MenuItemTarget.invoke), keyEquivalent: key)
        item.target = target
        return item
    }

    // MARK: - Icon

    private func updateIcon() {
        stopAnimation()
        switch appState.phase {
        case .recording:
            animate(StatusBarIcons.prerenderWaveFrames())
        case .transcribing:
            animate(StatusBarIcons.prerenderTranscribeFrames())
        case .preparing:
            setIcon(preparingIcon())
        case .needsAccessibility:
            setIcon(StatusBarIcons.drawLockIcon())
        case .inserted, .copied:
            setIcon(StatusBarIcons.drawCheckmarkIcon())
        case .error:
            setIcon(StatusBarIcons.drawWarningIcon())
        case .idle:
            setIcon(StatusBarIcons.logo())
        }
    }

    private func preparingIcon() -> NSImage {
        if case .loading(let fraction, _) = appState.model {
            return StatusBarIcons.drawDownloadProgress((fraction ?? 0) * 100)
        }
        return StatusBarIcons.logo()
    }

    private func animate(_ frames: [NSImage]) {
        guard let first = frames.first else { return }
        setIcon(first)
        var index = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1 / Self.ANIMATION_FPS, repeats: true) { [weak self] _ in
            index = (index + 1) % frames.count
            MainActor.assumeIsolated { self?.setIcon(frames[index]) }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func setIcon(_ image: NSImage) {
        image.isTemplate = true
        statusItem.button?.image = image
    }
}

final class MenuItemTarget: NSObject {
    let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func invoke() { handler() }
}
