import Foundation

/// Rewrites a transcription with the user's dictionary.
///
/// Matching is whole-word and case-insensitive, with Unicode-aware boundaries
/// so Polish and other accented words are not split in the middle. Longer
/// phrases are applied first, so "my work email" wins over "email".
public enum DictionaryEngine {
    public static func apply(_ entries: [DictionaryEntry], to text: String) -> String {
        let usable = entries
            .filter { !$0.spoken.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.spoken.count > $1.spoken.count }

        return usable.reduce(text) { current, entry in
            replace(entry, in: current)
        }
    }

    private static func replace(_ entry: DictionaryEntry, in text: String) -> String {
        guard let regex = pattern(for: entry.spoken) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let template = NSRegularExpression.escapedTemplate(for: entry.written)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func pattern(for spoken: String) -> NSRegularExpression? {
        let phrase = spoken
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "\\s+")
        let bounded = "(?<![\\p{L}\\p{N}])\(phrase)(?![\\p{L}\\p{N}])"
        return try? NSRegularExpression(pattern: bounded, options: [.caseInsensitive])
    }
}
