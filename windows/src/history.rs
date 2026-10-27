//! Finished dictations, kept so they can be found and copied later.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use uuid::Uuid;

use crate::storage;

/// Same fields as the macOS `HistoryEntry`. `appBundleID` holds the program's
/// executable name on Windows (e.g. `OUTLOOK.EXE`).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryEntry {
    #[serde(with = "storage::upper_uuid")]
    pub id: Uuid,
    #[serde(with = "storage::iso8601")]
    pub date: DateTime<Utc>,
    pub text: String,
    pub duration_seconds: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub audio_file_name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub app_name: Option<String>,
    #[serde(default, rename = "appBundleID", skip_serializing_if = "Option::is_none")]
    pub app_bundle_id: Option<String>,
}

pub struct History {
    path: PathBuf,
    pub entries: Vec<HistoryEntry>,
    pub load_warning: Option<String>,
}

/// Oldest entries are dropped past this many, so the file stays small.
pub const MAX_ENTRIES: usize = 5000;

impl History {
    pub fn load(path: PathBuf) -> Self {
        let (entries, load_warning) = storage::load_list_or_quarantine(&path);
        Self { path, entries, load_warning }
    }

    pub fn add(&mut self, entry: HistoryEntry) -> Result<(), String> {
        self.entries.insert(0, entry);
        self.entries.truncate(MAX_ENTRIES);
        self.save()
    }

    pub fn remove(&mut self, id: Uuid) -> Result<(), String> {
        self.entries.retain(|e| e.id != id);
        self.save()
    }

    pub fn clear(&mut self) -> Result<(), String> {
        self.entries.clear();
        self.save()
    }

    /// Newest first, filtered by a case-insensitive text query.
    pub fn search(&self, query: &str, limit: usize) -> Vec<HistoryEntry> {
        let needle = query.trim().to_lowercase();
        self.entries
            .iter()
            .filter(|e| needle.is_empty() || e.text.to_lowercase().contains(&needle))
            .take(limit)
            .cloned()
            .collect()
    }

    fn save(&self) -> Result<(), String> {
        storage::save_json(&self.path, &self.entries)
            .map_err(|err| format!("Could not save the history: {err}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(text: &str) -> HistoryEntry {
        HistoryEntry {
            id: Uuid::new_v4(),
            date: Utc::now(),
            text: text.into(),
            duration_seconds: 1.5,
            audio_file_name: None,
            app_name: Some("Notepad".into()),
            app_bundle_id: Some("notepad.exe".into()),
        }
    }

    #[test]
    fn newest_first_and_searchable() {
        let path = std::env::temp_dir().join(format!("warble-history-{}.json", Uuid::new_v4()));
        let mut history = History::load(path.clone());
        history.add(entry("Dzień dobry")).unwrap();
        history.add(entry("Hello there")).unwrap();
        assert_eq!(history.search("", 10)[0].text, "Hello there");
        assert_eq!(history.search("DZIEŃ", 10).len(), 1);

        let raw = std::fs::read_to_string(&path).unwrap();
        assert!(raw.contains("\"appBundleID\""));
        assert!(raw.contains("\"durationSeconds\""));
        assert_eq!(History::load(path).entries.len(), 2);
    }
}
