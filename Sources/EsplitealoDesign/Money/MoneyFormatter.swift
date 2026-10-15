import Foundation

/// Formats integer cents as US dollars: `$1,234.56`, in the Puerto Rico Spanish or US English convention.
///
/// Bills are always in US dollars, so only the *language* of the given locale matters: Spanish uses `es_PR`,
/// anything else `en_US`. (`es_419` would print `USD 1,234.56` and `es_ES` `1234,56 US$`.) Negative amounts use a true
/// minus sign (`−$1.00`), like the share text.
public struct MoneyFormatter: Sendable {
    public let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        let isSpanish = locale.language.languageCode?.identifier == "es"
        self.locale = Locale(identifier: isSpanish ? "es_PR" : "en_US")
    }

    private var isSpanish: Bool { locale.language.languageCode?.identifier == "es" }

    public func string(cents: Int) -> String {
        let negative = cents < 0
        let magnitude = cents.magnitude
        let dollars = Decimal(magnitude) / 100
        let formatted = dollars.formatted(.currency(code: "USD").locale(locale))
        return negative ? "−" + formatted : formatted
    }

    /// For VoiceOver: "12 dólares con 50 centavos" / "12 dollars and 50 cents".
    public func spokenString(cents: Int) -> String {
        let magnitude = cents.magnitude
        let dollars = magnitude / 100
        let remainder = magnitude % 100
        var parts: [String] = []
        if dollars > 0 || remainder == 0 { parts.append(unit(dollars, one: isSpanish ? "dólar" : "dollar", other: isSpanish ? "dólares" : "dollars")) }
        if remainder > 0 { parts.append(unit(remainder, one: isSpanish ? "centavo" : "cent", other: isSpanish ? "centavos" : "cents")) }
        let joined = parts.joined(separator: isSpanish ? " con " : " and ")
        guard cents < 0 else { return joined }
        return (isSpanish ? "menos " : "minus ") + joined
    }

    private func unit(_ count: UInt, one: String, other: String) -> String {
        "\(count) " + (count == 1 ? one : other)
    }
}
