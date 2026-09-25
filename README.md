<p align="center">
  <img src="Resources/AppIcon-1024.png" width="128" alt="Warble icon">
</p>

<h1 align="center">Warble</h1>

<p align="center">
  <strong>Free, local voice dictation for macOS.</strong><br>
  Hold a key, speak, let go. Your words appear wherever you type.<br>
  NVIDIA Parakeet runs on your Mac, so no audio or text ever leaves it.
</p>

<p align="center">
  <img src="docs-site/public/screenshots/history.png" width="820" alt="Warble main window with History">
</p>

## Features

- **Hold-to-talk or toggle** dictation on fn 🌐 or any key you pick.
- **Parakeet TDT v3 on-device** through [FluidAudio](https://github.com/FluidInference/FluidAudio), offline after a one-time download of about 500 MB.
- **Liquid Glass recording pill** with a live waveform, above every app and Space.
- **Searchable history** with the app each dictation went into and optional audio replay.
- **Dictionary** for names, jargon and text shortcuts like “my email”.
- **Setup window** that walks through permissions and the model download.
- **No account, no subscription, no telemetry.** MIT licensed.

## Install

Requires macOS 26 and Xcode 26 (Swift 6.2).

```bash
git clone https://github.com/pieralukasz/open-wispr-parakeet.git warble
cd warble
scripts/install.sh
```

The script builds a release, installs `~/Applications/Warble.app`, links the `warble` command into `~/.local/bin`, and opens the app. Setup takes it from there.

Coming from open-wispr? Warble imports `~/.config/open-wispr/config.json` on first launch. Quit the old app first, since both listen to the same key.

Uninstall with `scripts/uninstall.sh`, or `scripts/uninstall.sh --purge` to also delete settings, history and dictionary.

## Documentation

The full guide lives in [`docs-site`](docs-site), built with [Fumadocs](https://fumadocs.dev): dictating, the dictionary, settings, the CLI, the config file, privacy and troubleshooting.

```bash
cd docs-site && bun install && bun run dev
```

## Command line

```text
warble status                     Show hotkey, language, audio input and autostart
warble set-hotkey <key>           globe, rightoption, f5, ctrl+space, ...
warble set-language <code>        pl, en, auto, ...
warble transcribe-file <path>     Transcribe an audio file and print the text
warble enable-autostart           Start at login
```

## Development

```bash
swift test --disable-sandbox
WARBLE_PREVIEW=history .build/Warble.app/Contents/MacOS/warble start   # any screen on sample data
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and the architecture page in the docs.

## Credits

Warble grew out of [open-wispr](https://github.com/human37/open-wispr) by human37 (MIT). Speech recognition is NVIDIA Parakeet TDT v3 via [FluidAudio](https://github.com/FluidInference/FluidAudio) (Apache 2.0).

## License

MIT. See [LICENSE](LICENSE).
