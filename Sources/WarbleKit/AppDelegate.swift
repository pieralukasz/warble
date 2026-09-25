import AppKit

/// Wires the pieces together and walks the app from launch to listening:
/// load settings, get permissions, load Parakeet, then watch the hotkey.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    /// How often the Accessibility grant is re-checked while waiting for it.
    static let ACCESSIBILITY_POLL: Duration = .milliseconds(500)

    private let appState = AppState()
    private let history: HistoryStore
    private let dictionary: DictionaryStore
    private let recorder = AudioRecorder()
    private let sounds = SoundPlayer()
    private let hotkeys = HotkeyController()
    private let navigation = MainNavigation()
    private let playback = AudioPlayback()

    private var config = Config.load()
    private var settings: SettingsModel!
    private var dictation: DictationController!
    private var statusBar: StatusBarController!
    private var pill: RecordingPillController!
    private var windows: WindowCoordinator!
    private var modelLoader: ModelLoader!
    private var sleepWake: SleepWakeObserver?
    private var hasShownScreenRecordingAlert = false
    private var previewBackdrop: NSWindow?
    private var previewActivation: NSObjectProtocol?
    private var previewDeactivation: NSObjectProtocol?

    /// Close to the default macOS wallpapers' calm areas, light and dark.
    static let LIGHT_BACKDROP = NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1)
    static let DARK_BACKDROP = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)

    public override init() {
        if PreviewMode.isActive, let files = try? PreviewData.seed() {
            history = HistoryStore(fileURL: files.history)
            dictionary = DictionaryStore(fileURL: files.dictionary)
        } else {
            history = HistoryStore()
            dictionary = DictionaryStore()
        }
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        settings = SettingsModel(config: config, persists: !PreviewMode.isActive) { [weak self] in self?.apply($0) }
        dictation = DictationController(
            dependencies: .init(appState: appState, history: history, dictionary: dictionary, recorder: recorder, sounds: sounds),
            config: config,
            transcriber: ParakeetTranscriber(language: config.language)
        )
        dictation.onCaptureFailure = { [weak self] in self?.presentCaptureFailure($0) }
        recorder.levelHandler = { [appState] level in
            Task { @MainActor in appState.pushLevel(level) }
        }
        modelLoader = ModelLoader(appState: appState)
        let environment = makeEnvironment()
        windows = WindowCoordinator(environment: environment)
        pill = RecordingPillController(appState: appState)
        statusBar = StatusBarController(
            appState: appState,
            panel: environment.wrap(MenuBarPanel()),
            openSettings: { [weak self] in self?.openMain(.settings) }
        )
        sleepWake = SleepWakeObserver(
            willSleep: { [weak self] in self?.dictation.cancelForSleep() },
            didWake: { [weak self] in self?.configureRecorder(reload: true) }
        )

        configureFeedback()
        configureRecorder(reload: false)
        migrateAudioDeviceUIDIfNeeded()
        if Config.effectiveMaxRecordings(config.maxRecordings) == 0 {
            RecordingStore.deleteAllRecordings()
        }

        if let scene = PreviewMode.scene {
            runPreview(scene)
            return
        }
        let needsOnboarding = !(config.hasCompletedOnboarding?.value ?? false)
        if needsOnboarding { windows.showOnboarding() }
        Task { await startUp(askForPermissions: !needsOnboarding) }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        recorder.teardown()
    }

    /// Reopening the app from Finder or Spotlight shows the main window.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { windows.showMain() }
        return true
    }

    // MARK: - Start-up

    private func startUp(askForPermissions: Bool) async {
        if askForPermissions { await requestPermissions() }
        async let modelReady = modelLoader.load(using: dictation.transcriber)
        await waitForAccessibility()
        guard await modelReady else {
            appState.transition(to: .error("Speech model unavailable"))
            return
        }
        startListening()
    }

    /// Returning users skip onboarding, so ask for anything that was revoked since.
    private func requestPermissions() async {
        let source = config.audioCaptureSource
        await Task.detached {
            if source.includesMicrophone { Permissions.ensureMicrophone() }
            if source.includesSystemAudio { Permissions.ensureScreenRecording() }
        }.value
        if !AXIsProcessTrusted() {
            Permissions.promptAccessibility()
        }
    }

    private func waitForAccessibility() async {
        guard !AXIsProcessTrusted() else { return }
        appState.transition(to: .needsAccessibility)
        while !AXIsProcessTrusted() {
            try? await Task.sleep(for: Self.ACCESSIBILITY_POLL)
        }
        appState.transition(to: .preparing)
    }

    private func startListening() {
        hotkeys.listen(
            to: config.hotkeys,
            onKeyDown: { [weak self] in self?.dictation.handleKeyDown() },
            onKeyUp: { [weak self] in self?.dictation.handleKeyUp() }
        )
        appState.transition(to: .idle)
        print("Warble v\(AppInfo.version) ready · hotkey \(config.hotkeySummary()) · Parakeet v3")
    }

    private func retryModel() {
        Task {
            guard await modelLoader.load(using: dictation.transcriber) else { return }
            if AXIsProcessTrusted() { startListening() }
        }
    }

    // MARK: - Preview

    private func runPreview(_ scene: PreviewMode.Scene) {
        appState.model = .ready
        appState.transition(to: .idle)
        if let appearance = PreviewMode.appearance {
            NSApp.appearance = NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
        }
        Task {
            guard let window = await previewWindow(for: scene) else {
                print("Preview window not shown")
                return
            }
            print("Preview window \(window.windowNumber)")
            // The capture script waits for this line, so windows are shot as key.
            if NSApp.isActive { print("Preview active") }
            previewActivation = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated { window.makeKeyAndOrderFront(nil) }
                print("Preview active")
            }
            previewDeactivation = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
            ) { _ in
                print("Preview inactive")
            }
        }
    }

    /// The status item and the pill appear a moment after launch, so wait
    /// until the window is on screen before reporting its number.
    private func previewWindow(for scene: PreviewMode.Scene) async -> NSWindow? {
        switch scene {
        case .main(let name):
            return await keepKey(windows.showMain(section: name.section))
        case .onboarding(let step):
            return await keepKey(windows.showOnboarding(startingAt: OnboardingStep(rawValue: step) ?? .welcome))
        case .menuBar:
            let panel = await waitUntilVisible {
                statusBar.showPanel()
                return statusBar.panelWindow
            }
            return await settleOnBackdrop(panel)
        case .pill(let name):
            appState.transition(to: name.phase)
            if name == .recording { simulateSpeech() }
            return await settleOnBackdrop(await waitUntilVisible { pill.panel })
        }
    }

    /// Glass shows whatever sits behind it, so a capture of the panel or the
    /// pill alone depends on the screen. A plain window underneath makes
    /// every capture look the same, in the colors of the chosen appearance.
    private func settleOnBackdrop(_ window: NSWindow?) async -> NSWindow? {
        guard let window else { return nil }
        let backdrop = NSWindow(
            contentRect: window.frame.insetBy(dx: -40, dy: -40),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        backdrop.backgroundColor = isDark ? Self.DARK_BACKDROP : Self.LIGHT_BACKDROP
        backdrop.ignoresMouseEvents = true
        backdrop.isReleasedWhenClosed = false
        backdrop.level = window.level
        backdrop.order(.below, relativeTo: window.windowNumber)
        previewBackdrop = backdrop
        // Give the glass a moment to sample its new background.
        try? await Task.sleep(for: .milliseconds(400))
        return window
    }

    /// Activation right after launch can lose to the app that launched us,
    /// so ask again once the window is up; screenshots then show it as key.
    private func keepKey(_ window: NSWindow) async -> NSWindow {
        try? await Task.sleep(for: .milliseconds(300))
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func waitUntilVisible(_ window: () -> NSWindow?) async -> NSWindow? {
        for _ in 0..<40 {
            if let shown = window(), shown.isVisible, shown.windowNumber > 0 { return shown }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    /// A speech-like level pattern so the waveform has shape in screenshots.
    private func simulateSpeech() {
        for index in 0..<AppState.LEVEL_HISTORY_COUNT {
            let envelope = 0.45 + 0.4 * sin(Double(index) * 0.55) * sin(Double(index) * 0.21)
            appState.pushLevel(Float(max(0.08, envelope)))
        }
    }

    // MARK: - Settings

    private func apply(_ newConfig: Config) {
        let previous = config
        config = newConfig
        dictation.config = newConfig
        configureFeedback()

        if previous.language != newConfig.language {
            dictation.transcriber = ParakeetTranscriber(language: newConfig.language)
        }
        let deviceChanged = previous.audioInputDeviceUID != newConfig.audioInputDeviceUID
        let sourceChanged = previous.audioCaptureSource != newConfig.audioCaptureSource
        if deviceChanged || sourceChanged {
            configureRecorder(reload: true)
        }
        if sourceChanged && newConfig.audioCaptureSource.includesSystemAudio && !Permissions.ensureScreenRecording() {
            presentCaptureFailure(AudioCaptureError.screenRecordingPermissionRequired)
        }
        if previous.hotkeys != newConfig.hotkeys && hotkeys.isListening {
            startListening()
        }
        dictation.inserter = TextInserter()
    }

    private func configureFeedback() {
        appState.hotkeySummary = HotkeyLabel.describe(config.hotkeys)
        sounds.isEnabled = config.shouldPlaySounds?.value ?? true
        pill?.isEnabled = config.shouldShowRecordingPill?.value ?? true
    }

    private func configureRecorder(reload: Bool) {
        recorder.preferredDeviceID = AudioDeviceManager.resolveConfiguredDeviceID(
            uid: config.audioInputDeviceUID,
            legacyID: config.audioInputDeviceID
        )
        recorder.captureSource = config.audioCaptureSource
        if reload { recorder.reload() }
    }

    /// Older configs stored only the numeric device ID, which changes across reboots.
    private func migrateAudioDeviceUIDIfNeeded() {
        guard config.audioInputDeviceUID == nil,
              let legacyID = config.audioInputDeviceID,
              let uid = AudioDeviceManager.getDeviceUID(deviceID: legacyID) else { return }
        settings.update { $0.audioInputDeviceUID = uid }
    }

    // MARK: - Actions from the UI

    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(
            appState: appState,
            history: history,
            dictionary: dictionary,
            settings: settings,
            navigation: navigation,
            playback: playback,
            actions: AppActions(
                retryModel: { [weak self] in self?.retryModel() },
                openMain: { [weak self] section in self?.openMain(section) },
                retranscribe: { [weak self] url in self?.dictation.retranscribe(audioURL: url) },
                pauseHotkeys: { [weak self] isPaused in self?.pauseHotkeys(isPaused) },
                openOnboarding: { [weak self] in self?.windows.showOnboarding() },
                finishOnboarding: { [weak self] in self?.finishOnboarding() },
                setLaunchAtLogin: { [weak self] isOn in self?.setLaunchAtLogin(isOn) ?? false }
            )
        )
    }

    private func openMain(_ section: MainSection) {
        statusBar.closePanel()
        windows.showMain(section: section)
    }

    private func pauseHotkeys(_ isPaused: Bool) {
        if isPaused {
            hotkeys.stop()
        } else if appState.model.isReady && AXIsProcessTrusted() {
            startListening()
        }
    }

    private func finishOnboarding() {
        settings.update {
            $0.hasCompletedOnboarding = FlexBool(true)
            $0.launchAtLoginPrompted = FlexBool(true)
        }
        windows.closeOnboarding()
        windows.showMain(section: .history)
    }

    private func setLaunchAtLogin(_ isOn: Bool) -> Bool {
        do {
            if isOn { try LaunchAtLogin.enable() } else { try LaunchAtLogin.disable() }
        } catch {
            presentAlert(title: "Could not change the login setting", message: error.localizedDescription)
        }
        return LaunchAtLogin.isEnabled
    }

    /// Shown once per launch: every hotkey press would otherwise hit the same missing grant.
    private func presentCaptureFailure(_ error: Error) {
        guard (error as? AudioCaptureError) == .screenRecordingPermissionRequired,
              !hasShownScreenRecordingAlert else { return }
        hasShownScreenRecordingAlert = true
        let opensSettings = presentAlert(
            title: "Screen Recording permission required",
            message: AudioCaptureError.screenRecordingPermissionRequired.localizedDescription,
            primary: "Open System Settings"
        )
        if opensSettings { Permissions.openScreenRecordingSettings() }
    }

    @discardableResult
    private func presentAlert(title: String, message: String, primary: String = "OK") -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: primary)
        if primary != "OK" { alert.addButton(withTitle: "Later") }
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }
}
