import AppKit
import SwiftUI

/// The shared objects every Warble window reads from its SwiftUI environment.
@MainActor
struct AppEnvironment {
    let appState: AppState
    let history: HistoryStore
    let dictionary: DictionaryStore
    let settings: SettingsModel
    let navigation: MainNavigation
    let playback: AudioPlayback
    let actions: AppActions

    func wrap<Content: View>(_ view: Content) -> some View {
        view
            .environment(appState)
            .environment(history)
            .environment(dictionary)
            .environment(settings)
            .environment(navigation)
            .environment(playback)
            .environment(\.appActions, actions)
    }
}

/// Opens the main and onboarding windows. Warble lives in the menu bar, so it
/// only shows a Dock icon while one of its windows is open.
@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {
    private let environment: AppEnvironment
    private var mainWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    @discardableResult
    func showMain(section: MainSection? = nil) -> NSWindow {
        if let section { environment.navigation.section = section }
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window
        present(window)
        return window
    }

    @discardableResult
    func showOnboarding(startingAt step: OnboardingStep = .welcome) -> NSWindow {
        let window = onboardingWindow ?? makeOnboardingWindow(startingAt: step)
        onboardingWindow = window
        present(window)
        return window
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === onboardingWindow { onboardingWindow = nil }
        if closing === mainWindow {
            environment.playback.stop()
            mainWindow = nil
        }
        let othersOpen = [mainWindow, onboardingWindow].contains { $0 != nil && $0 !== closing }
        if !othersOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeMainWindow() -> NSWindow {
        let controller = NSHostingController(rootView: environment.wrap(MainView()))
        controller.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "Warble"
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 960, height: 640))
        window.setFrameAutosaveName("WarbleMainWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self
        if !window.setFrameUsingName("WarbleMainWindow") { window.center() }
        return window
    }

    private func makeOnboardingWindow(startingAt step: OnboardingStep) -> NSWindow {
        let controller = NSHostingController(rootView: environment.wrap(OnboardingView(initialStep: step)))
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
