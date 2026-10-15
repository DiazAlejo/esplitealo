import Foundation
import Testing

/// Spanish (Puerto Rico) is the development language and English the second. A missing translation must fail the
/// required `swift test` run, not show up as a Spanish string in the English app.
struct LocalizationCatalogTests {
    static let languages = ["es", "en"]

    private func catalog() throws -> StringCatalog {
        try StringCatalog(contentsOf: AppFiles.localizable)
    }

    @Test func spanishIsTheSourceLanguage() throws {
        #expect(try catalog().sourceLanguage == "es")
        #expect(try StringCatalog(contentsOf: AppFiles.infoPlistStrings).sourceLanguage == "es")
    }

    @Test func catalogIsPopulatedFromTheMockupStrings() throws {
        let keys = try catalog().keys
        // The mockups have well over two hundred user-facing strings; the catalog must not be a stub.
        #expect(keys.count >= 200)
        for key in ["home.scan", "home.photo", "review.continue", "people.add", "assign.title", "totals.share", "success.again"] {
            #expect(keys.contains(key), "missing \(key)")
        }
    }

    @Test func everyKeyExistsInBothLanguages() throws {
        for entry in try catalog().entries {
            for language in Self.languages {
                #expect(entry.localizations[language] != nil, "\(entry.key) has no \(language) translation")
            }
        }
    }

    @Test func everyKeyExistsInBothLanguagesInTheInfoPlistCatalog() throws {
        let entries = try StringCatalog(contentsOf: AppFiles.infoPlistStrings).entries
        #expect(!entries.isEmpty)
        for entry in entries {
            for language in Self.languages {
                #expect(entry.localizations[language] != nil, "\(entry.key) has no \(language) translation")
            }
        }
    }

    @Test func translationsAreFinishedAndNotEmpty() throws {
        for entry in try catalog().entries {
            for language in Self.languages {
                guard let localization = entry.localizations[language] else { continue }
                #expect(localization.states.allSatisfy { $0 == "translated" }, "\(entry.key) [\(language)] is not translated")
                #expect(localization.values.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                        "\(entry.key) [\(language)] is empty")
            }
        }
    }

    @Test func pluralsProvideOneAndOtherInBothLanguages() throws {
        for entry in try catalog().entries {
            for language in Self.languages {
                guard let localization = entry.localizations[language], localization.kind == .plural else { continue }
                #expect(Set(localization.values.keys) == ["one", "other"], "\(entry.key) [\(language)] plural categories")
            }
        }
    }

    @Test func bothLanguagesTakeTheSameArguments() throws {
        for entry in try catalog().entries {
            guard let es = entry.localizations["es"], let en = entry.localizations["en"] else { continue }
            let spanish = es.values.values.map(StringCatalog.placeholders(in:))
            let english = en.values.values.map(StringCatalog.placeholders(in:))
            let reference = spanish.first ?? []
            #expect(spanish.allSatisfy { $0 == reference }, "\(entry.key): Spanish variants differ in arguments")
            #expect(english.allSatisfy { $0 == reference }, "\(entry.key): English arguments differ from Spanish")
        }
    }

    @Test func keysAreLowercaseDottedNames() throws {
        for key in try catalog().keys {
            #expect(key.range(of: #"^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)+$"#, options: .regularExpression) != nil, "\(key)")
        }
    }

    @Test func spanishFollowsTheWordingRules() throws {
        // tú register; "marcar" for assigning; never "monto"; "añadir", not "agregar".
        let forbidden = ["monto", "asign", "agreg", "usted", "ustedes", "seleccion"]
        for entry in try catalog().entries {
            for text in entry.localizations["es"]?.values.values ?? [] {
                let lowercased = text.lowercased()
                for word in forbidden {
                    #expect(!lowercased.contains(word), "\(entry.key): Spanish text uses \"\(word)\"")
                }
            }
        }
    }

    @Test func houseVocabularyIsUsed() throws {
        let entries = Dictionary(uniqueKeysWithValues: try catalog().entries.map { ($0.key, $0) })
        func spanish(_ key: String) -> String { entries[key]?.localizations["es"]?.values["other"] ?? "" }
        #expect(spanish("totals.share") == "Compartir espliteo")
        #expect(spanish("people.add") == "Añadir persona")
        #expect(spanish("success.again") == "Comenzar otra cuenta")
        #expect(spanish("assign.title") == "Marcar artículos")
        #expect(spanish("review.title") == "Chequea el recibo")
        #expect(spanish("review.fixIt") == "Arreglarlo")
    }

    @Test func everyKeyUsedInTheAppSourcesExists() throws {
        let known = Set(try catalog().keys)
        let pattern = try NSRegularExpression(
            pattern: #"(?:Text|LocalizedStringKey|String\(localized:|LocalizedStringResource|Button|Label|Section|navigationTitle|accessibilityLabel|accessibilityHint)\(?\s*\(?\s*"([a-z][a-zA-Z0-9]*(?:\.[a-z][a-zA-Z0-9]*)+)""#
        )
        var missing: [String] = []
        for file in AppFiles.files(in: AppFiles.sources, extensions: ["swift"]) {
            let source = try AppFiles.text(file)
            let range = NSRange(source.startIndex..., in: source)
            for match in pattern.matches(in: source, range: range) {
                let key = (source as NSString).substring(with: match.range(at: 1))
                if !known.contains(key) { missing.append("\(file.lastPathComponent): \(key)") }
            }
        }
        #expect(missing.isEmpty, "keys used in code but missing from Localizable.xcstrings: \(missing)")
    }
}
