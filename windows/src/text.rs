//! Text clean-up applied to every transcription before it is typed.
//!
//! Ported from the macOS app (`TextPostProcessor.swift` and
//! `DictionaryEngine.swift`) so both platforms produce the same text from the
//! same dictionary. The tests mirror the Swift test cases.

use regex::{NoExpand, Regex, RegexBuilder};
use std::sync::OnceLock;

use crate::dictionary::DictionaryEntry;

/// Spoken punctuation, applied in this order (order matters: "semi colon"
/// becomes "semi:" because "colon" is matched first, exactly like on macOS).
const SPOKEN_PUNCTUATION: &[(&str, &str)] = &[
    (r"\bperiod\b", "."),
    (r"\bfull stop\b", "."),
    (r"\b[ck]a?r?ma\b", ","),
    (r"\bcomma\b", ","),
    (r"\bquestion mark\b", "?"),
    (r"\bexclamation mark\b", "!"),
    (r"\bexclamation point\b", "!"),
    (r"\bcolon\b", ":"),
    (r"\bsemicolon\b", ";"),
    (r"\bsemi colon\b", ";"),
    (r"\bellipsis\b", "..."),
    (r"\bdash\b", " —"),
    (r"\bhyphen\b", "-"),
    (r"\bopen quote\b", "\""),
    (r"\bclose quote\b", "\""),
    (r"\bopen paren\b", "("),
    (r"\bclose paren\b", ")"),
    (r"\bnew line\b", "\n"),
    (r"\bnewline\b", "\n"),
    (r"\bnew paragraph\b", "\n\n"),
];

fn punctuation_rules() -> &'static [(Regex, &'static str)] {
    static RULES: OnceLock<Vec<(Regex, &'static str)>> = OnceLock::new();
    RULES.get_or_init(|| {
        SPOKEN_PUNCTUATION
            .iter()
            .map(|(pattern, replacement)| {
                let regex = RegexBuilder::new(pattern)
                    .case_insensitive(true)
                    .build()
                    .expect("spoken punctuation pattern");
                (regex, *replacement)
            })
            .collect()
    })
}

/// Turns "hello comma world period" into "hello, world.".
pub fn spoken_punctuation(text: &str) -> String {
    static SPACE_BEFORE: OnceLock<Regex> = OnceLock::new();
    static NO_SPACE_AFTER: OnceLock<Regex> = OnceLock::new();

    let mut result = text.to_string();
    for (regex, replacement) in punctuation_rules() {
        result = regex.replace_all(&result, NoExpand(replacement)).into_owned();
    }
    let space_before = SPACE_BEFORE.get_or_init(|| Regex::new(r"\s+([.,?!:;])").unwrap());
    result = space_before.replace_all(&result, "$1").into_owned();
    let no_space_after = NO_SPACE_AFTER.get_or_init(|| Regex::new(r"([.,?!:;])(\w)").unwrap());
    no_space_after.replace_all(&result, "$1 $2").into_owned()
}

/// Rewrites a transcription with the user's dictionary.
///
/// Matching is whole-word and case-insensitive, with Unicode-aware
/// boundaries so Polish and other accented words are not split in the middle.
/// Longer phrases are applied first, so "my work email" wins over "email".
pub fn apply_dictionary(entries: &[DictionaryEntry], text: &str) -> String {
    let mut usable: Vec<&DictionaryEntry> = entries
        .iter()
        .filter(|entry| !entry.spoken.trim().is_empty())
        .collect();
    usable.sort_by(|a, b| b.spoken.chars().count().cmp(&a.spoken.chars().count()));

    usable
        .into_iter()
        .fold(text.to_string(), |current, entry| replace_phrase(&current, &entry.spoken, &entry.written))
}

fn replace_phrase(text: &str, spoken: &str, written: &str) -> String {
    let phrase = spoken
        .split_whitespace()
        .map(regex::escape)
        .collect::<Vec<_>>()
        .join(r"\s+");
    let Ok(regex) = RegexBuilder::new(&phrase).case_insensitive(true).build() else {
        return text.to_string();
    };

    let mut out = String::with_capacity(text.len());
    let mut copied_up_to = 0;
    let mut search_from = 0;
    while search_from <= text.len() {
        let Some(found) = regex.find_at(text, search_from) else { break };
        let before = text[..found.start()].chars().next_back();
        let after = text[found.end()..].chars().next();
        let bounded = !before.is_some_and(is_word_char) && !after.is_some_and(is_word_char);
        if bounded && !found.as_str().is_empty() {
            out.push_str(&text[copied_up_to..found.start()]);
            out.push_str(written);
            copied_up_to = found.end();
            search_from = found.end();
        } else {
            // Retry one character later so a rejected match does not hide a valid one.
            let step = text[found.start()..].chars().next().map_or(1, char::len_utf8);
            search_from = found.start() + step;
        }
    }
    out.push_str(&text[copied_up_to..]);
    out
}

fn is_word_char(c: char) -> bool {
    c.is_alphanumeric()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::dictionary::DictionaryEntry;

    fn p(text: &str) -> String {
        spoken_punctuation(text)
    }

    #[test]
    fn punctuation_matches_macos_behaviour() {
        assert_eq!(p("hello period"), "hello.");
        assert_eq!(p("one comma two"), "one, two");
        assert_eq!(p("how are you question mark"), "how are you?");
        assert_eq!(p("wow exclamation mark"), "wow!");
        assert_eq!(p("wow exclamation point"), "wow!");
        assert_eq!(p("note colon"), "note:");
        assert_eq!(p("first semicolon second"), "first; second");
        assert_eq!(p("wait ellipsis"), "wait...");
        assert_eq!(p("hello new line world"), "hello \n world");
        assert_eq!(p("hello new paragraph world"), "hello \n\n world");
        assert_eq!(p("he said open quote hello close quote"), "he said \" hello \"");
        assert_eq!(p("open paren note close paren"), "( note )");
        assert_eq!(p("hello Period"), "hello.");
        assert_eq!(p("hello comma how are you question mark"), "hello, how are you?");
        assert_eq!(p("hello , world"), "hello, world");
        assert_eq!(p("hello world"), "hello world");
        assert_eq!(p(""), "");
        assert_eq!(p("done full stop"), "done.");
        assert_eq!(p("one dash two"), "one  — two");
        assert_eq!(p("well hyphen known"), "well - known");
        assert_eq!(p("first semi colon second"), "first semi: second");
        assert_eq!(p("hello newline world"), "hello \n world");
        assert_eq!(p("hello,world"), "hello, world");
    }

    #[test]
    fn word_entry_fixes_casing_wherever() {
        let entries = [DictionaryEntry::word("GitHub")];
        assert_eq!(apply_dictionary(&entries, "push it to github and Github"), "push it to GitHub and GitHub");
    }

    #[test]
    fn replacement_expands_spoken_phrase() {
        let entries = [DictionaryEntry::replacement("my email", "lucas@example.com")];
        assert_eq!(
            apply_dictionary(&entries, "Send it to My  email please."),
            "Send it to lucas@example.com please."
        );
    }

    #[test]
    fn does_not_match_inside_longer_words() {
        let entries = [DictionaryEntry::word("AI")];
        assert_eq!(apply_dictionary(&entries, "said ai, not rain"), "said AI, not rain");
    }

    #[test]
    fn respects_polish_letter_boundaries() {
        let entries = [DictionaryEntry::replacement("kot", "Kot")];
        assert_eq!(apply_dictionary(&entries, "kotły i kot"), "kotły i Kot");
        let entries = [DictionaryEntry::word("Łódź")];
        assert_eq!(apply_dictionary(&entries, "jadę do łódź i złódźka"), "jadę do Łódź i złódźka");
    }

    #[test]
    fn longer_phrase_wins_over_its_prefix() {
        let entries = [
            DictionaryEntry::replacement("email", "EMAIL"),
            DictionaryEntry::replacement("work email", "me@work.com"),
        ];
        assert_eq!(apply_dictionary(&entries, "my work email"), "my me@work.com");
    }

    #[test]
    fn replacement_text_is_inserted_literally() {
        let entries = [DictionaryEntry::replacement("price", "$1 \\n")];
        assert_eq!(apply_dictionary(&entries, "the price"), "the $1 \\n");
    }

    #[test]
    fn blank_entries_are_ignored() {
        let entries = [DictionaryEntry::replacement("  ", "x")];
        assert_eq!(apply_dictionary(&entries, "hello world"), "hello world");
    }

    #[test]
    fn rejected_match_does_not_hide_a_later_one() {
        let entries = [DictionaryEntry::word("AI")];
        assert_eq!(apply_dictionary(&entries, "aai ai"), "aai AI");
    }
}
