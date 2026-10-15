import Foundation

public enum ChavitoLanguage: Sendable, Hashable {
    case spanish
    case english

    /// Spanish for any `es` locale, English otherwise (the app ships exactly these two).
    public init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "es" ? .spanish : .english
    }
}

public enum ChavitoAccessibility {
    /// Label strings are the ones in `design/mockups/_src/strings.js` (`mascot.expr`).
    public static func label(for expression: ChavitoExpression, in language: ChavitoLanguage) -> String {
        switch (language, expression) {
        case (.spanish, .neutral): "Chavito, el mapache"
        case (.spanish, .happy): "Chavito, el mapache, contento"
        case (.spanish, .thinking): "Chavito, el mapache, pensando"
        case (.spanish, .worried): "Chavito, el mapache, preocupado"
        case (.english, .neutral): "Chavito the raccoon"
        case (.english, .happy): "Chavito the raccoon, happy"
        case (.english, .thinking): "Chavito the raccoon, thinking"
        case (.english, .worried): "Chavito the raccoon, worried"
        }
    }

    /// `nil` means the mascot is decorative and must be hidden from VoiceOver.
    public static func description(
        for expression: ChavitoExpression,
        language: ChavitoLanguage,
        decorative: Bool
    ) -> String? {
        decorative ? nil : label(for: expression, in: language)
    }
}
