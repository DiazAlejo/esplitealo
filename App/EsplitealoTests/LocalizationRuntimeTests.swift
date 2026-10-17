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

    @Test func theBlockedBillWithNothingToCarryTheChargesSaysWhyInBothLanguages() {
        #expect(text("totals.nobodyItems.title", "en") == "Nobody has items to carry the tax or tip")
        #expect(text("totals.nobodyItems.title", "es") == "Nadie tiene artículos para repartir el impuesto o la propina")
        #expect(text("totals.nobodyItems.body", "en").contains("Fix the prices"))
        #expect(text("totals.nobodyItems.body", "es").contains("Arregla los precios"))
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

    // The typed symbols Xcode generates from the catalog (`STRING_CATALOG_GENERATE_SYMBOLS`): `Text(.navStep(2))`.
    // Screens use these for every string with arguments, instead of `String(format:)`.

    func resolve(_ resource: LocalizedStringResource, _ language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    @Test func generatedSymbolsResolveStaticStrings() {
        #expect(resolve(.homeScan, "es") == "Escanear recibo")
        #expect(resolve(.homeScan, "en") == "Scan receipt")
    }

    @Test func generatedSymbolsTakeTypedArgumentsAndPickPlurals() {
        #expect(resolve(.navStep(2), "es") == "Paso 2 de 5")
        #expect(resolve(.navStep(2), "en") == "Step 2 of 5")
        #expect(resolve(.assignProgress(3, 8), "en") == "3 of 8")
        #expect(resolve(.peopleAssigned(1), "es") == "1 artículo marcado")
        #expect(resolve(.peopleAssigned(3), "en") == "3 items assigned")
        #expect(resolve(.reviewDiff("$1.00"), "es") == "Diferencia: $1.00.")
    }
}
