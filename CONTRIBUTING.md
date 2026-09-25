# Contributing

Thanks for helping with Warble. Keep it local-first: nothing should send audio or text off the Mac.

## Getting started

```bash
swift build
swift test --disable-sandbox
scripts/install.sh    # build, bundle and install to ~/Applications
```

## Project structure

```text
Sources/WarbleKit/
├── AppDelegate.swift        # wiring and launch sequence
├── Dictation/               # DictationController, model loading, hotkeys, sounds
├── State/                   # AppState, SettingsModel, phases, permissions
├── Stores/                  # history, dictionary, JSON persistence
├── UI/                      # pill, main window, onboarding, settings
├── Preview/                 # WARBLE_PREVIEW sample-data mode
├── AudioRecorder.swift      # microphone and system audio capture
├── ParakeetTranscriber.swift
└── TextInserter.swift       # paste at the cursor, restore the clipboard
Sources/Warble/main.swift    # CLI entry point
docs-site/                   # Fumadocs documentation site
```

## Tests

Pure logic (dictionary matching, stats, audio levels, phases, stores, config) has unit tests. Microphone, system audio, Accessibility and the UI need a manual check on a Mac.

## Screenshots

`WARBLE_PREVIEW=<scene>` opens any screen on sample data without touching your real history or settings. `scripts/capture-screenshots.sh` renders every scene into `docs-site/public/screenshots`.

## Pull requests

1. Branch from `main`.
2. Add tests for logic changes.
3. Run `swift test`, and `bun run build` in `docs-site` for docs changes.
4. Include a screenshot for UI changes.

## License

Contributions are licensed under the MIT License.
