import Foundation

/// A minimal reader for Xcode String Catalogs (`.xcstrings`).
struct StringCatalog {
    struct Entry {
        let key: String
        let comment: String?
        /// Language code -> every text the language provides (one for a plain string, one per plural category otherwise).
        let localizations: [String: Localization]
    }

    struct Localization {
        enum Kind: Equatable { case plain, plural }
        let kind: Kind
        /// Plural category (or "other" for a plain string) -> text.
        let values: [String: String]
        let states: [String]
    }

    let sourceLanguage: String
    let entries: [Entry]

    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        sourceLanguage = root["sourceLanguage"] as? String ?? ""
        entries = strings.keys.sorted().map { key in
            let entry = strings[key] as? [String: Any] ?? [:]
            let localizations = (entry["localizations"] as? [String: Any] ?? [:]).mapValues(Self.localization(from:))
            return Entry(key: key, comment: entry["comment"] as? String, localizations: localizations)
        }
    }

    var keys: [String] { entries.map(\.key) }

    private static func localization(from raw: Any) -> Localization {
        let dictionary = raw as? [String: Any] ?? [:]
        if let unit = dictionary["stringUnit"] as? [String: Any] {
            return Localization(
                kind: .plain,
                values: ["other": unit["value"] as? String ?? ""],
                states: [unit["state"] as? String ?? ""]
            )
        }
        let plural = (dictionary["variations"] as? [String: Any])?["plural"] as? [String: Any] ?? [:]
        var values: [String: String] = [:]
        var states: [String] = []
        for (category, variant) in plural {
            let unit = (variant as? [String: Any])?["stringUnit"] as? [String: Any]
            values[category] = unit?["value"] as? String ?? ""
            states.append(unit?["state"] as? String ?? "")
        }
        return Localization(kind: .plural, values: values, states: states)
    }

    /// The `%` conversions of a format string, e.g. `["@", "d"]` for `"%1$@ x %2$lld"`, in argument order.
    static func placeholders(in format: String) -> [String] {
        let pattern = #"%(?!%)(?:(\d+)\$)?[-+ 0#]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?([@dDiuUxXoOfeEgGcCsSpaAF])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(format.startIndex..., in: format)
        var positional: [(Int, String)] = []
        for (offset, match) in regex.matches(in: format, range: range).enumerated() {
            let index = match.range(at: 1).location == NSNotFound
                ? offset + 1
                : Int((format as NSString).substring(with: match.range(at: 1)))!
            positional.append((index, (format as NSString).substring(with: match.range(at: 2))))
        }
        return positional.sorted { $0.0 < $1.0 }.map { $0.1 == "i" ? "d" : $0.1 }
    }
}
