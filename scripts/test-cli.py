#!/usr/bin/env python3
"""Exercise the built CLI with synthetic data only. Never launches or installs Warble."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

binary = Path(__file__).resolve().parents[1] / '.build/debug/warble'
assert binary.is_file(), 'Run swift build first'
count = 0
with tempfile.TemporaryDirectory(prefix='warble-cli-', dir=os.environ.get('TMPDIR')) as scratch:
    root = Path(scratch) / 'data'

    def run(*args, ok=True):
        global count
        result = subprocess.run([str(binary), '--data-dir', str(root), '--json', *args], capture_output=True, text=True)
        assert (result.returncode == 0) == ok, (args, result.stdout, result.stderr)
        assert not (result.stderr if ok else result.stdout), (args, result.stdout, result.stderr)
        value = json.loads(result.stdout if ok else result.stderr)
        if not ok:
            assert isinstance(value['error'], str)
        count += 1
        return value

    assert run('settings', 'show')['language'] == 'en'
    assert run('status')['historyCount'] == 0
    assert run('history', 'list') == []
    assert not root.exists(), 'Read-only commands created data'
    word = run('dictionary', 'words', 'add', 'Łukasz')
    assert run('dictionary', 'words', 'list')[0]['written'] == 'Łukasz'
    run('dictionary', 'words', 'add', 'łukasz', ok=False)
    run('dictionary', 'words', 'add', ' ', ok=False)
    replacement = run('dictionary', 'replacements', 'add', 'my email', 'test@example.invalid')
    assert len(run('dictionary', 'replacements', 'list')) == 1
    run('dictionary', 'words', 'remove', replacement['id'], ok=False)
    run('dictionary', 'words', 'remove', 'invalid', ok=False)
    with (root / 'daemon.lock').open('r+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        run('dictionary', 'words', 'add', 'blocked', ok=False)
    run('dictionary', 'words', 'remove', word['id'])
    run('dictionary', 'replacements', 'remove', replacement['id'])
    assert run('dictionary', 'words', 'list') == []
    identifier = str(uuid.uuid4())
    history = [{'id': identifier, 'date': '2026-01-01T10:00:00Z', 'text': 'Hello Łukasz', 'durationSeconds': 2, 'appName': 'Notes'}]
    (root / 'history.json').write_text(json.dumps(history))
    assert run('history', 'list', '--query', 'notes', '--limit', '1')[0]['id'].lower() == identifier
    assert run('history', 'show', identifier)['text'] == 'Hello Łukasz'
    assert len(run('history', 'export')) == 1
    assert run('history', 'list', '--query', 'absent') == []
    run('history', 'list', '--limit', '-1', ok=False)
    run('history', 'list', '--unknown', 'x', ok=False)
    run('history', 'show', str(uuid.uuid4()), ok=False)
    (root / 'config.json').write_text('{"language":"pl"}')
    assert run('settings', 'show')['language'] == 'pl'
    run('settings', 'set', 'language', 'en', ok=False)
    run('start', ok=False)
    run('set-language', 'en', ok=False)
    (root / 'dictionary.json').write_text('broken')
    run('dictionary', 'words', 'list', ok=False)
    run('dictionary', 'words', 'add', 'Test', ok=False)
    assert (root / 'dictionary.json').read_text() == 'broken'
    assert not list(root.glob('*.corrupt*'))
    (root / 'config.json').write_text('broken')
    run('settings', 'show', ok=False)
    assert (root / 'config.json').read_text() == 'broken'
help_result = subprocess.run([str(binary), '--help'], capture_output=True, text=True, check=True)
assert 'dictionary words' in help_result.stdout
print(f'PASS: {count} isolated JSON command checks plus help; fixtures removed; no app launched.')
