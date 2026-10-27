//! Types text at the cursor: put it on the clipboard, press Ctrl+V, then put
//! back what was on the clipboard before.

use arboard::Clipboard;
use enigo::{Direction, Enigo, Key, Keyboard, Settings};
use std::thread::sleep;
use std::time::Duration;

/// Virtual-key code of V. Using the code (not the character) keeps paste
/// working on every keyboard layout.
#[cfg(windows)]
const PASTE_KEY: Key = Key::Other(0x56);
#[cfg(target_os = "macos")]
const PASTE_KEY: Key = Key::Other(9);
#[cfg(not(any(windows, target_os = "macos")))]
const PASTE_KEY: Key = Key::Unicode('v');

#[cfg(target_os = "macos")]
const PASTE_MODIFIER: Key = Key::Meta;
#[cfg(not(target_os = "macos"))]
const PASTE_MODIFIER: Key = Key::Control;

pub fn insert(text: &str, keep_on_clipboard: bool) -> Result<(), String> {
    let mut clipboard = Clipboard::new().map_err(|e| format!("The clipboard is not available: {e}"))?;
    let previous = if keep_on_clipboard { None } else { clipboard.get_text().ok() };
    clipboard
        .set_text(text.to_string())
        .map_err(|e| format!("Could not copy the text: {e}"))?;
    sleep(Duration::from_millis(40));

    // A modifier from the shortcut may still be held (Toggle mode, slow fingers);
    // Ctrl+Shift+V or Alt+Ctrl+V would do something else in many apps.
    crate::platform::wait_for_modifiers_released();
    let mut enigo = Enigo::new(&Settings::default()).map_err(|e| format!("Cannot press keys: {e}"))?;
    let pressed = enigo
        .key(PASTE_MODIFIER, Direction::Press)
        .and_then(|_| enigo.key(PASTE_KEY, Direction::Click));
    let _ = enigo.key(PASTE_MODIFIER, Direction::Release);
    pressed.map_err(|e| format!("Could not paste (the text is on the clipboard): {e}"))?;

    if let Some(previous) = previous {
        // Give the target app time to read the clipboard before restoring it.
        sleep(Duration::from_millis(350));
        let _ = clipboard.set_text(previous);
    }
    Ok(())
}

pub fn copy(text: &str) -> Result<(), String> {
    Clipboard::new()
        .and_then(|mut c| c.set_text(text.to_string()))
        .map_err(|e| format!("Could not copy the text: {e}"))
}
