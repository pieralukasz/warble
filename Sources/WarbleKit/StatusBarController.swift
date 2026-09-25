import AppKit

/// The menu bar item: an icon that mirrors the dictation phase and a short
/// menu that is rebuilt every time it opens, so it never shows stale state.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    struct Actions {
        let openMain: () -> Void
        let openSettings: () -> Void
        let selectLanguage: (String) -> Void
    }

    /// Recent dictations offered in the menu for one-click copying.
    static let RECENT_COUNT = 5
    static let ANIMATION_FPS = 30.0

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appState: AppState
    private let history: HistoryStore
    private let actions: Actions
    private var animationTimer: Timer?
    private var menuTargets: [MenuItemTarget] = []

    init(appState: AppState, history: HistoryStore, actions: Actions) {
        self.appState = appState
        self.history = history
        self.actions = actions
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.setAccessibilityLabel("Warble")
        updateIcon()
        observeContinuously({ [weak self] in
            _ = self?.appState.phase
            _ = self?.appState.model
        }, onChange: { [weak self] in
            self?.updateIcon()
        })
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menuTargets = []

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        menu.addItem(item("Open Warble", key: "o", action: actions.openMain))
        menu.addItem(item("Settings…", key: ",", action: actions.openSettings))
        menu.addItem(.separator())

        addRecent(to: menu)
        menu.addItem(languageMenu())
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Warble", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func statusLine() -> String {
        if case .loading(let fraction, let detail) = appState.model {
            let percent = fraction.map { " · \(Int($0 * 100))%" } ?? ""
            return "\(detail)\(percent)"
        }
        if case .failed(let message) = appState.model {
            return "Model failed: \(message)"
        }
        let hint = appState.hotkeySummary.isEmpty ? "" : " · hold \(appState.hotkeySummary)"
        return appState.phase == .idle ? "Ready\(hint)" : appState.phase.statusText
    }

    private func addRecent(to menu: NSMenu) {
        let recent = history.entries.prefix(Self.RECENT_COUNT)
        guard !recent.isEmpty else { return }

        let header = NSMenuItem(title: "Recent · click to copy", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for entry in recent {
            let title = entry.text.count > 48 ? String(entry.text.prefix(47)) + "…" : entry.text
            menu.addItem(item(title, key: "") { Self.copy(entry.text) })
        }
        menu.addItem(.separator())
    }

    private func languageMenu() -> NSMenuItem {
        let current = Config.load().language
        let name = Config.supportedLanguages.first { $0.code == current }?.name ?? current
        let parent = NSMenuItem(title: "Language: \(name)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for language in Config.supportedLanguages {
            let option = item(language.name, key: "") { [actions] in actions.selectLanguage(language.code) }
            option.state = language.code == current ? .on : .off
            submenu.addItem(option)
        }
        parent.submenu = submenu
        return parent
    }

    private func item(_ title: String, key: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = MenuItemTarget(handler: action)
        menuTargets.append(target)
        let item = NSMenuItem(title: title, action: #selector(MenuItemTarget.invoke), keyEquivalent: key)
        item.target = target
        return item
    }

    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
