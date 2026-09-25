import Foundation

public struct LanguageOption: Equatable, Sendable {
    public let code: String
    public let name: String
}

extension Config {
    /// Languages supported by Parakeet TDT v3 in the pinned FluidAudio revision.
    public static let supportedLanguages: [LanguageOption] = [
        LanguageOption(code: "auto", name: "Auto-Detect"),
        LanguageOption(code: "en", name: "English"),
        LanguageOption(code: "pl", name: "Polish"),
        LanguageOption(code: "es", name: "Spanish"),
        LanguageOption(code: "fr", name: "French"),
        LanguageOption(code: "de", name: "German"),
        LanguageOption(code: "it", name: "Italian"),
        LanguageOption(code: "pt", name: "Portuguese"),
        LanguageOption(code: "ro", name: "Romanian"),
        LanguageOption(code: "nl", name: "Dutch"),
        LanguageOption(code: "da", name: "Danish"),
        LanguageOption(code: "sv", name: "Swedish"),
        LanguageOption(code: "fi", name: "Finnish"),
        LanguageOption(code: "hu", name: "Hungarian"),
        LanguageOption(code: "et", name: "Estonian"),
        LanguageOption(code: "lv", name: "Latvian"),
        LanguageOption(code: "lt", name: "Lithuanian"),
        LanguageOption(code: "mt", name: "Maltese"),
        LanguageOption(code: "cs", name: "Czech"),
        LanguageOption(code: "sk", name: "Slovak"),
        LanguageOption(code: "sl", name: "Slovenian"),
        LanguageOption(code: "hr", name: "Croatian"),
        LanguageOption(code: "bs", name: "Bosnian"),
        LanguageOption(code: "ru", name: "Russian"),
        LanguageOption(code: "uk", name: "Ukrainian"),
        LanguageOption(code: "be", name: "Belarusian"),
        LanguageOption(code: "bg", name: "Bulgarian"),
        LanguageOption(code: "sr", name: "Serbian"),
        LanguageOption(code: "el", name: "Greek"),
    ]
}
