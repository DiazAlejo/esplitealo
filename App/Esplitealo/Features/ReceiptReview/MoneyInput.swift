import Foundation

/// What people type into a price or an amount field, as integer cents. Anything that is not clearly an amount is
/// `nil`: the screen asks again instead of guessing.
///
/// Accepted: digits with an optional `.` or `,` decimal separator and at most two decimals (`12`, `12.5`, `12,50`,
/// `.50`), a leading `$`, and `,` as the thousands separator in `1,234` and `1,234.56`. Nothing negative, nothing
/// above $999,999.99, and only ASCII digits.
enum MoneyInput {
    static let maximumCents = 99_999_999

    static func cents(from text: String) -> Int? {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("$") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }) else { return nil }

        let parts = split(text)
        // Nine digits of dollars is far above the maximum and cannot overflow the multiplication below.
        guard let (whole, fraction) = parts, !(whole.isEmpty && fraction.isEmpty), whole.count <= 9, let dollars = whole.isEmpty ? 0 : Int(whole) else {
            return nil
        }
        let cents = dollars * 100 + (fraction.isEmpty ? 0 : Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0))!)
        return cents <= maximumCents ? cents : nil
    }

    /// The text a field starts with: dollars, a dot and two decimals, whatever the language.
    static func editableText(cents: Int) -> String {
        let magnitude = cents.magnitude
        let remainder = magnitude % 100
        let text = "\(magnitude / 100)." + (remainder < 10 ? "0\(remainder)" : "\(remainder)")
        return cents < 0 ? "-" + text : text
    }

    // MARK: Parsing

    /// The digits before and after the decimal separator, or `nil` when the text is not a well-formed amount.
    private static func split(_ text: String) -> (whole: String, fraction: String)? {
        let dots = text.filter { $0 == "." }.count
        let commas = text.filter { $0 == "," }.count

        switch (dots, commas) {
        case (0, 0):
            return (text, "")
        case (1, 0):
            return decimal(text, separator: ".", grouping: false)
        case (1, _):
            // "1,234.56": the dot is the decimal separator, so it has to come last.
            guard let dot = text.firstIndex(of: "."), let lastComma = text.lastIndex(of: ","), lastComma < dot else { return nil }
            return decimal(text, separator: ".", grouping: true)
        case (0, 1):
            // One comma: "12,50" is a decimal comma, "1,234" a thousands separator.
            let after = text.drop { $0 != "," }.dropFirst()
            if after.count != 3 { return decimal(text, separator: ",", grouping: false) }
            return grouped(text).map { ($0, "") }
        case (0, _):
            return grouped(text).map { ($0, "") }
        default:
            return nil
        }
    }

    private static func decimal(_ text: String, separator: Character, grouping: Bool) -> (String, String)? {
        let pieces = text.split(separator: separator, maxSplits: 1, omittingEmptySubsequences: false)
        guard pieces.count == 2 else { return nil }
        let fraction = pieces[1]
        guard fraction.count <= 2, fraction.allSatisfy(\.isNumber) else { return nil }
        let whole = pieces[0]
        if grouping, whole.contains(",") {
            guard let digits = grouped(String(whole)) else { return nil }
            return (digits, String(fraction))
        }
        guard whole.allSatisfy(\.isNumber) else { return nil }
        return (String(whole), String(fraction))
    }

    /// "1,234,567" as "1234567": one to three digits, then groups of exactly three.
    private static func grouped(_ text: String) -> String? {
        let groups = text.split(separator: ",", omittingEmptySubsequences: false)
        guard groups.count > 1, let first = groups.first, (1 ... 3).contains(first.count) else { return nil }
        guard groups.allSatisfy({ $0.allSatisfy(\.isNumber) }), groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
        return groups.joined()
    }
}
