//! The user's dictionary: word spellings and spoken-phrase replacements.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use uuid::Uuid;

use crate::storage;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Kind {
    /// Fixes the spelling or casing of a word, e.g. "github" becomes "GitHub".
    Word,
    /// Expands a spoken phrase, e.g. "my email" becomes an address.
    Replacement,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DictionaryEntry {
    #[serde(with = "storage::upper_uuid")]
    pub id: Uuid,
    pub kind: Kind,
    /// What Parakeet is expected to produce; matched case-insensitively.
    pub spoken: String,
    /// What Warble types instead. For `Word` it equals the canonical spelling.
    pub written: String,
    #[serde(with = "storage::iso8601")]
    pub created_at: DateTime<Utc>,
}

impl DictionaryEntry {
    pub fn word(spelling: &str) -> Self {
        Self::new(Kind::Word, spelling, spelling)
    }

    pub fn replacement(spoken: &str, written: &str) -> Self {
        Self::new(Kind::Replacement, spoken, written)
    }

    fn new(kind: Kind, spoken: &str, written: &str) -> Self {
        Self {
            id: Uuid::new_v4(),
            kind,
            spoken: spoken.to_string(),
            written: written.to_string(),
            created_at: Utc::now(),
        }
    }
}

pub struct Dictionary {
    path: PathBuf,
    pub entries: Vec<DictionaryEntry>,
    pub load_warning: Option<String>,
}

impl Dictionary {
    pub fn load(path: PathBuf) -> Self {
        let (entries, load_warning) = storage::load_list_or_quarantine(&path);
        Self { path, entries, load_warning }
    }

    /// Adds an entry, replacing one with the same spoken text in the same category.
    /// Blank spoken text is rejected.
    pub fn add(&mut self, kind: Kind, spoken: &str, written: &str) -> Result<DictionaryEntry, String> {
        let spoken = spoken.trim();
        let written = written.trim();
        if spoken.is_empty() {
            return Err("The text cannot be empty.".into());
        }
        if kind == Kind::Replacement && written.is_empty() {
            return Err("The replacement cannot be empty.".into());
        }
        let written = if kind == Kind::Word { spoken } else { written };
        let entry = DictionaryEntry::new(kind, spoken, written);
        self.entries
            .retain(|e| !(e.kind == kind && e.spoken.to_lowercase() == spoken.to_lowercase()));
        self.entries.insert(0, entry.clone());
        self.save()?;
        Ok(entry)
    }

    pub fn remove(&mut self, id: Uuid) -> Result<(), String> {
        self.entries.retain(|e| e.id != id);
        self.save()
    }

    fn save(&self) -> Result<(), String> {
        storage::save_json(&self.path, &self.entries)
            .map_err(|err| format!("Could not save the dictionary: {err}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_file() -> PathBuf {
        std::env::temp_dir().join(format!("warble-dict-{}.json", Uuid::new_v4()))
    }

    #[test]
    fn reads_the_macos_file_format() {
        let path = temp_file();
        std::fs::write(
            &path,
            r#"[{"createdAt":"2026-10-01T08:00:00Z","id":"0B1C2D3E-4F50-4A6B-8C7D-9E0F1A2B3C4D","kind":"replacement","spoken":"my email","written":"lucas@example.com"}]"#,
        )
        .unwrap();
        let dictionary = Dictionary::load(path.clone());
        assert!(dictionary.load_warning.is_none());
        assert_eq!(dictionary.entries.len(), 1);
        assert_eq!(dictionary.entries[0].kind, Kind::Replacement);

        let json = serde_json::to_string(&dictionary.entries[0]).unwrap();
        assert!(json.contains(r#""id":"0B1C2D3E-4F50-4A6B-8C7D-9E0F1A2B3C4D""#));
        assert!(json.contains(r#""createdAt":"2026-10-01T08:00:00Z""#));
    }

    #[test]
    fn duplicates_replace_case_insensitively_within_a_kind() {
        let path = temp_file();
        let mut dictionary = Dictionary::load(path.clone());
        dictionary.add(Kind::Word, "github", "").unwrap();
        dictionary.add(Kind::Word, "  GitHub ", "").unwrap();
        dictionary.add(Kind::Replacement, "github", "GH").unwrap();
        assert_eq!(dictionary.entries.len(), 2);
        assert_eq!(dictionary.entries[1].written, "GitHub");

        let reloaded = Dictionary::load(path);
        assert_eq!(reloaded.entries.len(), 2);
    }

    #[test]
    fn blank_text_is_rejected() {
        let mut dictionary = Dictionary::load(temp_file());
        assert!(dictionary.add(Kind::Word, "   ", "").is_err());
        assert!(dictionary.add(Kind::Replacement, "x", " ").is_err());
        assert!(dictionary.entries.is_empty());
    }
}
