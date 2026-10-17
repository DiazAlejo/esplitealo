import Foundation
import Testing

/// The App Store listing drafts in `docs/store/es.md` and `docs/store/en.md`. Every field is a `### Heading` followed by
/// one fenced `text` block; the block is what gets pasted into App Store Connect, so that is what is counted.
///
/// Limits are Apple's, from App Store Connect Help ("Platform version information", "App information"):
/// name 2 to 30 characters, subtitle 30, promotional text 170, description 4000, what's new 4000, keywords 100 bytes,
/// App Review notes 4000 bytes. Keywords and notes are counted in UTF-8 bytes, the rest in characters.
struct StoreListingTests {
    enum Unit { case characters, bytes }

    struct Limit {
        let field: String
        let minimum: Int
        let maximum: Int
        let unit: Unit
    }

    static let limits = [
        Limit(field: "App name", minimum: 2, maximum: 30, unit: .characters),
        Limit(field: "Subtitle", minimum: 1, maximum: 30, unit: .characters),
        Limit(field: "Promotional text", minimum: 1, maximum: 170, unit: .characters),
        Limit(field: "Description", minimum: 1, maximum: 4000, unit: .characters),
        Limit(field: "Keywords", minimum: 1, maximum: 100, unit: .bytes),
        Limit(field: "What's new", minimum: 1, maximum: 4000, unit: .characters),
        Limit(field: "Review notes", minimum: 1, maximum: 4000, unit: .bytes),
    ]

    static let placeholderFields = ["Support URL", "Marketing URL", "Privacy policy URL", "Contact"]
    static let otherFields = ["Primary category", "Secondary category", "Age rating", "Copyright"]

    static let languages = ["es", "en"]

    private func listing(_ language: String) throws -> StoreListing {
        try StoreListing(contentsOf: AppFiles.root.appendingPathComponent("docs/store/\(language).md"))
    }

    // MARK: Parser

    @Test func parserReadsTheFencedBlockUnderEachHeading() throws {
        let listing = StoreListing(text: """
        # Title

        ### One
        Some prose that is not counted.

        ```text
        first
        ```

        ### Two

        ```text
        line a
        line b
        ```
        """)
        #expect(listing.fields["One"] == "first")
        #expect(listing.fields["Two"] == "line a\nline b")
        #expect(listing.fields.count == 2)
    }

    @Test func parserIgnoresFencedBlocksThatAreNotText() throws {
        let listing = StoreListing(text: """
        ### One

        ```bash
        echo no
        ```
        """)
        #expect(listing.fields["One"] == nil)
    }

    // MARK: Limits

    @Test(arguments: languages) func everyFieldExists(language: String) throws {
        let listing = try listing(language)
        let required = Self.limits.map(\.field) + Self.placeholderFields + Self.otherFields
        for field in required {
            #expect(listing.fields[field] != nil, "docs/store/\(language).md has no \"\(field)\" block")
        }
    }

    @Test(arguments: languages) func everyFieldIsWithinAppleLimits(language: String) throws {
        let listing = try listing(language)
        for limit in Self.limits {
            guard let value = listing.fields[limit.field] else {
                Issue.record("docs/store/\(language).md has no \"\(limit.field)\" block")
                continue
            }
            let count = limit.unit == .bytes ? value.utf8.count : value.count
            let unit = limit.unit == .bytes ? "bytes" : "characters"
            #expect(count >= limit.minimum, "\(language) \(limit.field): \(count) \(unit), needs at least \(limit.minimum)")
            #expect(count <= limit.maximum, "\(language) \(limit.field): \(count) \(unit), the limit is \(limit.maximum)")
        }
    }

    @Test(arguments: languages) func keywordsAreCommaSeparatedWithoutWastedBytes(language: String) throws {
        let value = try #require(listing(language).fields["Keywords"])
        #expect(!value.contains(", "), "\(language): no space after a comma, it costs a byte")
        #expect(!value.contains("\n"), "\(language): keywords are one line")
        let words = value.split(separator: ",").map(String.init)
        #expect(words.allSatisfy { $0.count > 2 }, "\(language): every keyword is longer than two characters")
        let normalized = words.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        #expect(Set(normalized).count == normalized.count, "\(language): a keyword is repeated")
    }

    // MARK: Placeholders and tone

    @Test(arguments: languages) func urlsAndContactStayPlaceholders(language: String) throws {
        let listing = try listing(language)
        for field in Self.placeholderFields {
            let value = try #require(listing.fields[field])
            #expect(value.contains("TODO"), "\(language) \(field) must say TODO until the owner provides it")
        }
        let everything = listing.fields.values.joined(separator: "\n").lowercased()
        for forbidden in ["github", "diazalejo", "gmail", "alejandro"] {
            #expect(!everything.contains(forbidden), "\(language): \"\(forbidden)\" must not appear in the listing")
        }
    }

    @Test(arguments: languages) func wordsTheProductNeverUses(language: String) throws {
        let text = try listing(language).fields.values.joined(separator: "\n").lowercased()
        for word in ["monto", "ivu"] {
            #expect(text.range(of: "\\b\(word)\\b", options: .regularExpression) == nil, "\(language): \"\(word)\" must not appear")
        }
    }

    @Test(arguments: languages) func noOtherBrandsInKeywordsAndNoPaymentAppClaims(language: String) throws {
        let listing = try listing(language)
        let brands = ["venmo", "paypal", "zelle", "cash app", "apple cash", "splitwise", "tricount", "splitser", "ath m", "athm", "apple pay"]
        let keywords = try #require(listing.fields["Keywords"]).lowercased()
        for brand in brands {
            #expect(!keywords.contains(brand), "\(language): the keywords must not name \"\(brand)\"")
        }
        // Everywhere else a payment app may only be named to say what Esplitéalo is not; none of these may be named at all.
        let everything = listing.fields.values.joined(separator: "\n").lowercased()
        for brand in ["venmo", "paypal", "zelle", "cash app", "splitwise", "tricount", "ath m", "athm"] {
            #expect(!everything.contains(brand), "\(language): \"\(brand)\" must not appear in the listing")
        }
    }

    @Test(arguments: languages) func noLikenessOfTheTelevisionCharacter(language: String) throws {
        let text = try listing(language).fields.values.joined(separator: "\n").lowercased()
        for word in ["chavo", "barril", "barrel", "gorra", "striped", "rayas", "camiseta a rayas"] {
            #expect(!text.contains(word), "\(language): \"\(word)\" must not appear in the listing")
        }
    }

    @Test func spanishIsPuertoRicanAndNeverUsesTheFormalRegister() throws {
        let text = try listing("es").fields.values.joined(separator: "\n").lowercased()
        for word in ["usted", "ustedes", "agregar", "asignar"] {
            #expect(text.range(of: "\\b\(word)\\b", options: .regularExpression) == nil, "es: \"\(word)\" must not appear")
        }
    }

    @Test func theSpanishListingHoldsTheSameFieldsAsTheEnglishOne() throws {
        #expect(try Set(listing("es").fields.keys) == Set(listing("en").fields.keys))
    }
}

/// `### Heading` followed (possibly after prose) by the first fenced `text` block.
struct StoreListing {
    let fields: [String: String]

    init(contentsOf url: URL) throws {
        self.init(text: try String(contentsOf: url, encoding: .utf8))
    }

    init(text: String) {
        var fields: [String: String] = [:]
        var heading: String?
        var block: [String]?
        for line in text.components(separatedBy: "\n") {
            if block != nil {
                if line.hasPrefix("```") {
                    if let heading, fields[heading] == nil { fields[heading] = block?.joined(separator: "\n") }
                    block = nil
                } else {
                    block?.append(line)
                }
            } else if line.hasPrefix("### ") {
                heading = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if line == "```text" {
                block = []
            } else if line.hasPrefix("```") {
                // A fenced block of another kind: skip it.
                block = nil
                heading = nil
            }
        }
        self.fields = fields
    }
}
