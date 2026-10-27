//! JSON files under the Warble data folder, in the same format as the macOS
//! app, so a `dictionary.json` copied from a Mac works on Windows unchanged.

use serde::{de::DeserializeOwned, Deserialize, Deserializer, Serialize, Serializer};
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use chrono::{DateTime, SecondsFormat, Utc};

/// Where Warble keeps its settings, dictionary and history.
///
/// `WARBLE_DATA_DIR` overrides it (tests, fixtures). On Windows the default is
/// `%APPDATA%\Warble`. Elsewhere it is a separate `Warble-Windows-dev` folder so
/// a development run on a Mac never touches the real macOS app's data.
pub fn data_dir() -> PathBuf {
    if let Some(dir) = std::env::var_os("WARBLE_DATA_DIR") {
        return PathBuf::from(dir);
    }
    let base = dirs::data_dir().unwrap_or_else(|| PathBuf::from("."));
    if cfg!(windows) {
        base.join("Warble")
    } else {
        base.join("Warble-Windows-dev")
    }
}

/// Where the speech model is downloaded:
/// `%LOCALAPPDATA%\io.github.pieralukasz.warble\models` on Windows, outside the
/// installer's own `%LOCALAPPDATA%\Warble` folder so reinstalls keep the model.
pub fn models_dir() -> PathBuf {
    if let Some(dir) = std::env::var_os("WARBLE_MODELS_DIR") {
        return PathBuf::from(dir);
    }
    let base = dirs::data_local_dir().unwrap_or_else(|| PathBuf::from("."));
    if cfg!(windows) {
        base.join("io.github.pieralukasz.warble").join("models")
    } else {
        base.join("Warble-Windows-dev").join("models")
    }
}

/// Returns `Ok(None)` when the file does not exist yet.
pub fn load_json<T: DeserializeOwned>(path: &Path) -> io::Result<Option<T>> {
    match fs::read(path) {
        Ok(bytes) => serde_json::from_slice(&bytes)
            .map(Some)
            .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err)),
        Err(err) if err.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(err) => Err(err),
    }
}

/// Writes pretty JSON through a temporary file so a crash never leaves half a file.
pub fn save_json<T: Serialize>(path: &Path, value: &T) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let json = serde_json::to_vec_pretty(value).map_err(io::Error::other)?;
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, json)?;
    fs::rename(&tmp, path)
}

/// Loads a list, moving an unreadable file aside instead of overwriting it later.
/// Returns the list and a warning to show the user when the file was bad.
pub fn load_list_or_quarantine<T: DeserializeOwned>(path: &Path) -> (Vec<T>, Option<String>) {
    match load_json::<Vec<T>>(path) {
        Ok(list) => (list.unwrap_or_default(), None),
        Err(err) => {
            let stamp = Utc::now().timestamp();
            let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("data");
            let backup = path.with_file_name(format!("{stem}.corrupt-{stamp}.json"));
            let moved = fs::rename(path, &backup);
            let warning = match moved {
                Ok(()) => format!(
                    "Could not read {}: {err}. The old file was kept as {}.",
                    path.display(),
                    backup.display()
                ),
                Err(move_err) => format!(
                    "Could not read {}: {err}. Moving it aside also failed: {move_err}",
                    path.display()
                ),
            };
            (Vec::new(), Some(warning))
        }
    }
}

/// Dates as Swift's `.iso8601` strategy writes them: `2026-10-27T09:30:00Z`.
pub mod iso8601 {
    use super::*;

    pub fn serialize<S: Serializer>(date: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&date.to_rfc3339_opts(SecondsFormat::Secs, true))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<DateTime<Utc>, D::Error> {
        let raw = String::deserialize(d)?;
        DateTime::parse_from_rfc3339(&raw)
            .map(|date| date.with_timezone(&Utc))
            .map_err(serde::de::Error::custom)
    }
}

/// UUIDs as Swift encodes them: upper case.
pub mod upper_uuid {
    use super::*;
    use uuid::Uuid;

    pub fn serialize<S: Serializer>(id: &Uuid, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&id.hyphenated().to_string().to_uppercase())
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Uuid, D::Error> {
        let raw = String::deserialize(d)?;
        Uuid::parse_str(&raw).map_err(serde::de::Error::custom)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("warble-test-{name}-{}", uuid::Uuid::new_v4()));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn missing_file_is_empty_without_warning() {
        let dir = temp_dir("missing");
        let (list, warning) = load_list_or_quarantine::<String>(&dir.join("x.json"));
        assert!(list.is_empty());
        assert!(warning.is_none());
    }

    #[test]
    fn corrupt_file_is_moved_aside_not_lost() {
        let dir = temp_dir("corrupt");
        let path = dir.join("dictionary.json");
        fs::write(&path, b"{not json").unwrap();
        let (list, warning) = load_list_or_quarantine::<String>(&path);
        assert!(list.is_empty());
        assert!(warning.unwrap().contains("corrupt-"));
        assert!(!path.exists());
        let kept: Vec<_> = fs::read_dir(&dir).unwrap().collect();
        assert_eq!(kept.len(), 1);
    }

    #[test]
    fn save_then_load_round_trips() {
        let dir = temp_dir("roundtrip");
        let path = dir.join("nested").join("list.json");
        save_json(&path, &vec!["a".to_string(), "b".to_string()]).unwrap();
        let loaded: Vec<String> = load_json(&path).unwrap().unwrap();
        assert_eq!(loaded, vec!["a", "b"]);
    }
}
