---
name: warble-cli
description: Use when managing Warble dictionary and history.
version: 0.1.0
author: Lucas Piera, Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [warble, cli, dictation, dictionary]
    related_skills: []
---

# Warble CLI

Use the existing native `warble` executable for headless dictionary edits, history reads/exports and read-only settings. No server, credentials, UI automation or model download is needed for data commands.

## When to Use

- List/add/remove canonical words and spoken-text replacements.
- Find dictations, fetch a record by UUID, export history as JSON.
- Inspect settings and data paths without launching the app.
- Do not use for real-time recording control or audio export; neither is implemented here.

## Prerequisites

macOS 26 and Swift 6.2/Xcode 26 command-line tools; Python 3 for the isolated smoke test. Run all commands from this repository root through `terminal` with that working directory. Use `read_file` and `search_files` for source inspection. Never assume an installed binary includes the current changes.

## How to Run

Build without installing:

```text
terminal(command="swift build", workdir="<repository-root>")
terminal(command=".build/debug/warble --help", workdir="<repository-root>")
```

The command examples below use `.build/debug/warble`; an explicitly verified installed version may also be used. Do not run `scripts/install.sh` unless the user authorizes replacement of the installed app.

## Quick Reference

```bash
.build/debug/warble dictionary words list
.build/debug/warble dictionary words add 'Łukasz'
.build/debug/warble dictionary words remove '<UUID>'
.build/debug/warble dictionary replacements list
.build/debug/warble dictionary replacements add 'my email' 'test@example.invalid'
.build/debug/warble dictionary replacements remove '<UUID>'
.build/debug/warble history list --query 'Notes' --limit 20
.build/debug/warble history show '<UUID>'
.build/debug/warble history export
.build/debug/warble settings show
.build/debug/warble --json status
```

Invoke those through `terminal`. Quote text arguments. All data commands emit JSON on stdout; `--json` is optional and goes before the command. Errors emit `{"error":"message"}` on stderr with exit 1; success is exit 0. Dates are ISO-8601. Lists are arrays; show/add/remove return a record object; settings/status return objects. `status --json` is also accepted. Human-readable legacy `status` is different: use structured status for read-only data inspection.

## Procedure

1. Run `--help` from the built binary to confirm available commands. Use only the needed dataset: history is private dictated text.
2. For tests use `python3 scripts/test-cli.py` through `terminal`. It creates synthetic fixtures under `TMPDIR`, removes them afterward, and never starts or installs the app. For manual fixtures set `FIXTURE_DIR` to a dedicated disposable directory, then invoke `.build/debug/warble --data-dir "$FIXTURE_DIR" --json dictionary words list`. Global options must precede the command.
3. Before real dictionary writes, obtain the requested word/replacement and list the relevant category. Quit Warble first: mutations take its daemon lock and fail if held. Do not kill the app automatically. Duplicate spoken text is rejected case-insensitively within its category; remove the exact listed UUID before adding an updated rule.
4. After mutation, list that category again and verify the UUID/text. Writes also atomically save and read back internally. Restart Warble to load the edited dictionary.
5. For exports, capture stdout or redirect to a **new** file selected by the user. Never redirect over dictionary/history/config files: shell redirection truncates before the CLI reads. Check JSON parsing and the returned record count before reporting success.

## Pitfalls

- Default dictionary/history location is the user's Application Support `Warble` directory; config remains in `.config/warble/config.json` under the user's home. Structured status reports the resolved paths and counts, **not daemon health**.
- `--data-dir` puts dictionary, history, config and lock together. It is supported only for data commands, not `start`, transcription, autostart or legacy setters. Never point a fixture at live data or symlink its files to live data.
- Reads never create default files, migrate legacy config, quarantine corrupt records or load the speech model. Missing files return empty lists/default settings; corrupt files fail unchanged.
- Settings and history commands are intentionally read-only. Existing `set-hotkey`/`set-language` remain legacy commands, outside fixture isolation, and may migrate/write real configuration. Do not use them in smoke tests.
- Dictionary text is trimmed; empty text fails. Removal requires the full UUID and correct category. Existing duplicates from older versions are not silently cleaned up.
- Export is a JSON snapshot, not an audio archive. Reads can see the latest atomically saved snapshot while the app runs; no live UI synchronization is provided.
- Do not infer permissions, microphone health or successful transcription from these tests.

## Verification

Run through `terminal` at the repository root:

```bash
swift build
swift test --disable-sandbox
python3 scripts/test-cli.py
```

The smoke script verifies JSON output/errors, Unicode, dictionary round trips, duplicates, lock contention, history filtering/show/export, isolated config reads, invalid options and corrupt-file preservation. `Tests/WarbleKitTests/DataCLITests.swift` covers shared command logic and global-option parsing. Report exact test results, changed files and any remaining limitations; do not commit, push or replace the installed app unless explicitly asked.
