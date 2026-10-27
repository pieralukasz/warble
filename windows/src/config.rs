//! Settings, saved as `config.json` in the data folder as soon as they change.

use serde::{Deserialize, Serialize};
use std::path::Path;

use crate::storage;

pub const DEFAULT_HOTKEY: &str = "Ctrl+Shift+Space";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Config {
    /// A global shortcut such as `Ctrl+Shift+Space` or `Alt+F9`.
    pub hotkey: String,
    /// Press once to start and once to stop, instead of holding the key.
    pub toggle_mode: bool,
    /// Turn "comma", "period", "new line" and similar words into punctuation.
    pub spoken_punctuation: bool,
    /// Show the small status pill at the bottom of the screen.
    pub show_pill: bool,
    /// Keep the dictated text on the clipboard instead of restoring what was there.
    pub keep_on_clipboard: bool,
    /// Name of the microphone to use; `None` means the Windows default.
    pub microphone: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            hotkey: DEFAULT_HOTKEY.into(),
            toggle_mode: false,
            spoken_punctuation: false,
            show_pill: true,
            keep_on_clipboard: false,
            microphone: None,
        }
    }
}

impl Config {
    /// A missing or unreadable file gives the defaults; the second value is a warning.
    pub fn load(path: &Path) -> (Self, Option<String>) {
        match storage::load_json::<Config>(path) {
            Ok(config) => (config.unwrap_or_default(), None),
            Err(err) => (Self::default(), Some(format!("Settings could not be read ({err}); using defaults."))),
        }
    }

    pub fn save(&self, path: &Path) -> Result<(), String> {
        storage::save_json(path, self).map_err(|err| format!("Could not save settings: {err}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_fields_take_defaults() {
        let config: Config = serde_json::from_str(r#"{"toggleMode": true}"#).unwrap();
        assert!(config.toggle_mode);
        assert_eq!(config.hotkey, DEFAULT_HOTKEY);
        assert!(config.show_pill);
    }

    #[test]
    fn default_hotkey_parses_as_a_global_shortcut() {
        use std::str::FromStr;
        use tauri_plugin_global_shortcut::Shortcut;
        assert!(Shortcut::from_str(DEFAULT_HOTKEY).is_ok());
        // The settings page records shortcuts from KeyboardEvent.code values.
        for combo in ["Ctrl+Alt+KeyD", "Shift+F9", "Ctrl+Digit1", "Alt+Backquote"] {
            assert!(Shortcut::from_str(combo).is_ok(), "{combo}");
        }
    }
}
