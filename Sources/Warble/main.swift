import AppKit
import Foundation
import WarbleKit

setvbuf(stdout, nil, _IOLBF, 0)
setvbuf(stderr, nil, _IOLBF, 0)

let version = AppInfo.version

func printUsage() {
    print("""
    warble v\(version) — Local Parakeet v3 voice dictation for macOS

    USAGE:
        warble start                Start the dictation daemon
        warble set-hotkey <key>     Set the push-to-talk hotkey
        warble get-hotkey           Show current hotkey
        warble set-language <code>  Set the language (e.g. pl, en, auto)
        warble transcribe-file <path>  Transcribe a local audio file with Parakeet v3
        warble enable-autostart     Start the daemon automatically at login
        warble disable-autostart    Stop starting the daemon at login
        warble status               Show configuration and status
        warble --help               Show this help message

    HOTKEY EXAMPLES:
        warble set-hotkey globe             Globe/fn key (default)
        warble set-hotkey rightoption        Right Option key
        warble set-hotkey rightcmd           Right Command key
        warble set-hotkey f5                 F5 key
        warble set-hotkey ctrl+space         Ctrl + Space
    """)
}

func cmdStart() {
    guard DaemonLock.acquire() else {
        print("warble is already running; look for the waveform icon in the menu bar.")
        return
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let delegate = AppDelegate()
    app.delegate = delegate

    signal(SIGINT) { _ in
        print("\nStopping warble...")
        exit(0)
    }

    app.run()
}

func cmdSetHotkey(_ keyString: String) {
    guard let parsed = KeyCodes.parse(keyString) else {
        print("Error: Unknown key '\(keyString)'")
        print("Run 'warble --help' for examples")
        exit(1)
    }

    var config = Config.load()
    config.hotkey = HotkeyConfig(keyCode: parsed.keyCode, modifiers: parsed.modifiers)

    do {
        try config.save()
        let description = KeyCodes.describe(
            keyCode: parsed.keyCode,
            modifiers: parsed.modifiers
        )
        print("Hotkey set to: \(description)")
    } catch {
        print("Error saving config: \(error.localizedDescription)")
        exit(1)
    }
}

func cmdSetLanguage(_ language: String) {
    let validCodes = Config.supportedLanguages.map(\.code)
    guard validCodes.contains(language) else {
        print("Error: Unknown language '\(language)'")
        print("Available: \(validCodes.joined(separator: ", "))")
        exit(1)
    }

    var config = Config.load()
    config.language = language

    do {
        try config.save()
        let name = Config.supportedLanguages.first(where: { $0.code == language })?.name
            ?? language
        print("Language set to: \(name) (\(language))")
    } catch {
        print("Error saving config: \(error.localizedDescription)")
        exit(1)
    }
}

/// Resolves the bundled binary the LaunchAgent should run. Falls back to the
/// installed Warble.app when the CLI was invoked through a symlink on PATH,
/// since a LaunchAgent pointing outside the bundle loses its TCC grants.
func autostartExecutablePath() -> String? {
    if let path = LaunchAtLogin.defaultExecutablePath() { return path }
    return AppBundleLaunch.findAppBundle()?
        .appendingPathComponent("Contents/MacOS/warble").path
}

func cmdEnableAutostart() {
    guard let executablePath = autostartExecutablePath() else {
        print("Error: Warble.app not found — install it before enabling autostart.")
        exit(1)
    }

    do {
        try LaunchAtLogin.enable(executablePath: executablePath)
        print("Autostart enabled: \(LaunchAtLogin.plistURL.path)")
        print("Takes effect at the next login; the running daemon is left alone.")
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

func cmdDisableAutostart() {
    do {
        try LaunchAtLogin.disable()
        print("Autostart disabled")
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

func cmdGetHotkey() {
    print("Current hotkey: \(Config.load().hotkeySummary())")
}

func cmdStatus() {
    let config = Config.load()
    let languageName = Config.supportedLanguages
        .first(where: { $0.code == config.language })?.name ?? config.language
    let toggleMode = config.toggleMode?.value ?? false

    print("warble v\(version)")
    print("Config:      \(Config.configFile.path)")
    print("Hotkey:      \(config.hotkeySummary())")
    print("Engine:      Parakeet v3")
    print("Audio input: \(config.audioCaptureSource.displayName)")
    print("Language:    \(languageName) (\(config.language))")
    print("Toggle:      \(toggleMode ? "on (press to start/stop)" : "off (hold to talk)")")
    print("Autostart:   \(LaunchAtLogin.isEnabled ? "on (starts at login)" : "off")")
}

func cmdTranscribeFile(_ path: String) {
    let audioURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: audioURL.path) else {
        print("Error: Audio file not found: \(audioURL.path)")
        exit(1)
    }

    let config = Config.load()
    let transcriber = ParakeetTranscriber(language: config.language)
    transcriber.spokenPunctuation = config.spokenPunctuation?.value ?? false

    do {
        try transcriber.prepare()
        print(try transcriber.transcribe(audioURL: audioURL))
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

let args = CommandLine.arguments
let rawCommand = args.count > 1 ? args[1] : nil
let command: String? = {
    if let rawCommand, rawCommand.hasPrefix("-psn_") { return "start" }
    // Finder, Launchpad, and `open` run the bundled binary with no arguments at
    // all on current macOS, so a bare launch from inside the bundle means "start
    // the daemon". Only older systems passed the -psn_ argument above. A bare CLI
    // build outside a bundle still prints usage.
    if rawCommand == nil, AppBundleLaunch.isRunningInsideAppBundle { return "start" }
    return rawCommand
}()

switch command {
case "start":
    if AppBundleLaunch.relaunchThroughAppBundleIfNeeded() {
        exit(0)
    }
    cmdStart()
case "set-hotkey":
    guard args.count > 2 else {
        print("Usage: warble set-hotkey <key>")
        exit(1)
    }
    cmdSetHotkey(args[2])
case "set-language":
    guard args.count > 2 else {
        print("Usage: warble set-language <code>")
        print("Examples: pl, en, auto")
        exit(1)
    }
    cmdSetLanguage(args[2])
case "get-hotkey":
    cmdGetHotkey()
case "enable-autostart":
    cmdEnableAutostart()
case "disable-autostart":
    cmdDisableAutostart()
case "status":
    cmdStatus()
case "transcribe-file":
    guard args.count > 2 else {
        print("Usage: warble transcribe-file <audio-path>")
        exit(1)
    }
    cmdTranscribeFile(args[2])
case "--help", "-h", "help":
    printUsage()
case nil:
    printUsage()
default:
    print("Unknown command: \(command!)")
    printUsage()
    exit(1)
}
