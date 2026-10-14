import Foundation

enum MoneyFormatting {
    static func usd(cents: Int) -> String {
        let negative = cents < 0
        let amount = abs(cents)
        let dollars = amount / 100
        let remainder = amount % 100
        let sign = negative ? "−" : ""
        return "\(sign)$\(dollars).\(String(format: "%02d", remainder))"
    }
}
