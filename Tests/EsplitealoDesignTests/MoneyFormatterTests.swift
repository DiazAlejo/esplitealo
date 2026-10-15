import Foundation
import Testing
@testable import EsplitealoDesign

struct MoneyFormatterTests {
    static let locales = [Locale(identifier: "es_PR"), Locale(identifier: "en_US")]

    @Test(arguments: locales)
    func formatsIntegerCentsAsDollars(locale: Locale) {
        let formatter = MoneyFormatter(locale: locale)
        #expect(formatter.string(cents: 0) == "$0.00")
        #expect(formatter.string(cents: 5) == "$0.05")
        #expect(formatter.string(cents: 99) == "$0.99")
        #expect(formatter.string(cents: 1250) == "$12.50")
        #expect(formatter.string(cents: 100_000) == "$1,000.00")
        #expect(formatter.string(cents: 123_456) == "$1,234.56")
    }

    @Test(arguments: locales)
    func negativeAmountsUseATrueMinusSignLikeTheShareText(locale: Locale) {
        let formatter = MoneyFormatter(locale: locale)
        #expect(formatter.string(cents: -1) == "−$0.01")
        #expect(formatter.string(cents: -123_456) == "−$1,234.56")
    }

    @Test func spanishAndEnglishAgreeOnTheDollarFormat() {
        for cents in [0, 1, 99, 1250, 123_456, -250] {
            #expect(MoneyFormatter(locale: Locale(identifier: "es_PR")).string(cents: cents)
                == MoneyFormatter(locale: Locale(identifier: "en_US")).string(cents: cents))
        }
    }

    @Test func otherRegionsStillGetPuertoRicoStyleDollars() {
        // `es_419` would print "USD 1,234.56" and `es_ES` "1234,56 US$"; bills are in US dollars, so
        // only the language is taken from the locale.
        for identifier in ["es_419", "es_ES", "es_MX", "en_GB", "fr_FR", "de_DE"] {
            let formatter = MoneyFormatter(locale: Locale(identifier: identifier))
            #expect(formatter.string(cents: 123_456) == "$1,234.56", "\(identifier)")
        }
    }

    @Test func formatterPicksTheLocaleFromTheLanguage() {
        #expect(MoneyFormatter(locale: Locale(identifier: "es_US")).locale.identifier == "es_PR")
        #expect(MoneyFormatter(locale: Locale(identifier: "en_PR")).locale.identifier == "en_US")
    }

    @Test func largeAmountsDoNotOverflowOrLosePrecision() {
        let formatter = MoneyFormatter(locale: Locale(identifier: "en_US"))
        #expect(formatter.string(cents: 99_999_999_999) == "$999,999,999.99")
        #expect(formatter.string(cents: Int.max).hasPrefix("$"))
    }

    @Test func spokenAmountReadsDollarsAndCents() {
        let spanish = MoneyFormatter(locale: Locale(identifier: "es_PR"))
        let english = MoneyFormatter(locale: Locale(identifier: "en_US"))
        #expect(spanish.spokenString(cents: 1250) == "12 dólares con 50 centavos")
        #expect(spanish.spokenString(cents: 100) == "1 dólar")
        #expect(spanish.spokenString(cents: 1) == "1 centavo")
        #expect(english.spokenString(cents: 1250) == "12 dollars and 50 cents")
        #expect(english.spokenString(cents: 100) == "1 dollar")
        #expect(english.spokenString(cents: 1) == "1 cent")
        #expect(english.spokenString(cents: -250) == "minus 2 dollars and 50 cents")
        #expect(spanish.spokenString(cents: -250) == "menos 2 dólares con 50 centavos")
        #expect(english.spokenString(cents: 0) == "0 dollars")
    }
}
