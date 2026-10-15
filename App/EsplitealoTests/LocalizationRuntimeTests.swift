import Foundation
import Testing
@testable import Esplitealo

/// The catalog is compiled into the app; these check that the compiled strings resolve per language,
/// including plurals and the positional arguments that the unit tests in `AppResourceTests` only read as JSON.
struct LocalizationRuntimeTests {
    func text(_ key: String, _ language: String, _ arguments: [any CVarArg] = []) -> String {
        let path = Bundle.main.path(forResource: language, ofType: "lproj")!
        let bundle = Bundle(path: path)!
        let format = bundle.localizedString(forKey: key, value: "⚠️ missing", table: nil)
        return String(format: format, locale: Locale(identifier: language), arguments: arguments)
    }

    @Test func developmentLanguageIsSpanishAndEnglishIsAvailable() {
        #expect(Bundle.main.developmentLocalization == "es")
        #expect(Set(Bundle.main.localizations).isSuperset(of: ["es", "en"]))
    }

    @Test func simpleStringsResolveInBothLanguages() {
        #expect(text("home.scan", "es") == "Escanear recibo")
        #expect(text("home.scan", "en") == "Scan receipt")
        #expect(text("totals.share", "es") == "Compartir espliteo")
        #expect(text("totals.share", "en") == "Share breakdown")
    }

    @Test func pluralsPickTheRightForm() {
        #expect(text("people.assigned", "es", [1]) == "1 artículo marcado")
        #expect(text("people.assigned", "es", [3]) == "3 artículos marcados")
        #expect(text("people.assigned", "en", [1]) == "1 item assigned")
        #expect(text("people.assigned", "en", [3]) == "3 items assigned")
    }

    @Test func positionalArgumentsKeepTheirOrderInBothLanguages() {
        #expect(text("assign.progress", "es", [3, 8]) == "3 de 8")
        #expect(text("assign.progress", "en", [3, 8]) == "3 of 8")
        #expect(text("review.warn.items", "en", ["$101.00", "$110.00"]) == "Your items add up to **$101.00**, but the receipt subtotal says **$110.00**.")
    }

    @Test func pluralWithAnotherArgumentUsesTheNumberAsThePluralArgument() {
        #expect(text("people.remove.had", "es", [1, "Héctor"]) == "Héctor tiene 1 artículo marcado.")
        #expect(text("people.remove.had", "es", [2, "Héctor"]) == "Héctor tiene 2 artículos marcados.")
        #expect(text("people.remove.had", "en", [2, "Héctor"]) == "Héctor has 2 items assigned.")
        #expect(text("totals.round.pool", "en", ["Tax", 1, "Ana"]) == "Tax: 1¢ of leftovers goes to Ana.")
        #expect(text("totals.round.pool", "en", ["Tax", 3, "Ana and Ben"]) == "Tax: 3¢ of leftovers go to Ana and Ben.")
    }

    @Test func infoPlistStringsAreLocalized() {
        func info(_ key: String, _ language: String) -> String {
            let path = Bundle.main.path(forResource: language, ofType: "lproj")!
            return Bundle(path: path)!.localizedString(forKey: key, value: "⚠️ missing", table: "InfoPlist")
        }
        #expect(info("NSCameraUsageDescription", "es").contains("cámara"))
        #expect(info("NSCameraUsageDescription", "en").contains("camera"))
    }
}
