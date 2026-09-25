import Foundation

/// A user rule applied to every transcription before it is typed.
public struct DictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// Fixes the spelling or casing of a word, e.g. "github" becomes "GitHub".
        case word
        /// Expands a spoken phrase, e.g. "my email" becomes an address.
        case replacement
    }

    public var id: UUID
    public var kind: Kind
    /// What Parakeet is expected to produce; matched case-insensitively.
    public var spoken: String
    /// What Warble types instead. For `.word` it equals the canonical spelling.
    public var written: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        spoken: String,
        written: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.spoken = spoken
        self.written = written
        self.createdAt = createdAt
    }

    public static func word(_ spelling: String) -> DictionaryEntry {
        DictionaryEntry(kind: .word, spoken: spelling, written: spelling)
    }

    public static func replacement(_ spoken: String, with written: String) -> DictionaryEntry {
        DictionaryEntry(kind: .replacement, spoken: spoken, written: written)
    }
}
