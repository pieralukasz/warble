import XCTest
@testable import WarbleKit

final class DictionaryEngineTests: XCTestCase {
    func testWordEntryFixesCasingWherever() {
        let entries = [DictionaryEntry.word("GitHub")]

        let result = DictionaryEngine.apply(entries, to: "push it to github and Github")

        XCTAssertEqual(result, "push it to GitHub and GitHub")
    }

    func testReplacementExpandsSpokenPhrase() {
        let entries = [DictionaryEntry.replacement("my email", with: "lucas@example.com")]

        let result = DictionaryEngine.apply(entries, to: "Send it to My  email please.")

        XCTAssertEqual(result, "Send it to lucas@example.com please.")
    }

    func testDoesNotMatchInsideLongerWords() {
        let entries = [DictionaryEntry.word("AI")]

        let result = DictionaryEngine.apply(entries, to: "said ai, not rain")

        XCTAssertEqual(result, "said AI, not rain")
    }

    func testRespectsPolishLetterBoundaries() {
        let entries = [DictionaryEntry.replacement("kot", with: "Kot")]

        let result = DictionaryEngine.apply(entries, to: "kotły i kot")

        XCTAssertEqual(result, "kotły i Kot")
    }

    func testLongerPhraseWinsOverItsPrefix() {
        let entries = [
            DictionaryEntry.replacement("email", with: "EMAIL"),
            DictionaryEntry.replacement("work email", with: "me@work.com"),
        ]

        let result = DictionaryEngine.apply(entries, to: "my work email")

        XCTAssertEqual(result, "my me@work.com")
    }

    func testReplacementTextIsInsertedLiterally() {
        let entries = [DictionaryEntry.replacement("price", with: "$1 \\n")]

        let result = DictionaryEngine.apply(entries, to: "the price")

        XCTAssertEqual(result, "the $1 \\n")
    }

    func testBlankEntriesAreIgnored() {
        let entries = [DictionaryEntry.replacement("  ", with: "x")]

        let result = DictionaryEngine.apply(entries, to: "hello world")

        XCTAssertEqual(result, "hello world")
    }
}
