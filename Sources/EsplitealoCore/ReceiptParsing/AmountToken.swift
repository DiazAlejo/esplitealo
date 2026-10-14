import Foundation

struct AmountToken: Equatable {
    enum Shape: Equatable {
        case integer
        case decimalDot
        case decimalComma
        case ambiguousGroup
        case grouped
    }

    let raw: String
    let digits: String
    let shape: Shape
    let separator: Character?
    let digitsAfterSeparator: Int?
    let isNegative: Bool

    static func parse(_ token: String) -> AmountToken? {
        var s = token.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        var negative = false
        if s.hasPrefix("(") && s.hasSuffix(")") {
            negative = true
            s = String(s.dropFirst().dropLast())
        }
        if s.hasPrefix("-") {
            negative = true
            s = String(s.dropFirst())
        } else if s.hasPrefix("+") {
            s = String(s.dropFirst())
        }
        if s.hasSuffix("-") {
            negative = true
            s = String(s.dropLast())
        }

        s = stripCurrencyPrefix(s)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

        guard !s.isEmpty else { return nil }
        if looksLikeDateOrPhone(s) { return nil }

        let cleaned = s.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !cleaned.isEmpty else { return nil }

        let dotCount = cleaned.filter { $0 == "." }.count
        let commaCount = cleaned.filter { $0 == "," }.count

        if dotCount == 0 && commaCount == 0 {
            guard cleaned.allSatisfy(\.isNumber) else { return nil }
            return AmountToken(
                raw: token,
                digits: cleaned,
                shape: .integer,
                separator: nil,
                digitsAfterSeparator: nil,
                isNegative: negative
            )
        }

        if dotCount > 0 && commaCount > 0 {
            guard let lastSep = cleaned.lastIndex(where: { $0 == "." || $0 == "," }) else { return nil }
            let sep = cleaned[lastSep]
            let intPart = String(cleaned[..<lastSep]).filter(\.isNumber)
            let fracPart = String(cleaned[cleaned.index(after: lastSep)...]).filter(\.isNumber)
            return AmountToken(
                raw: token,
                digits: intPart + fracPart,
                shape: sep == "." ? .decimalDot : .decimalComma,
                separator: sep,
                digitsAfterSeparator: fracPart.count,
                isNegative: negative
            )
        }

        let sep: Character = dotCount > 0 ? "." : ","
        let parts = cleaned.split(separator: sep, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            if parts.count > 2 {
                return AmountToken(
                    raw: token,
                    digits: parts.joined().filter(\.isNumber),
                    shape: .grouped,
                    separator: sep,
                    digitsAfterSeparator: nil,
                    isNegative: negative
                )
            }
            return nil
        }
        let intPart = String(parts[0])
        let fracPart = String(parts[1])
        guard intPart.allSatisfy(\.isNumber), fracPart.allSatisfy(\.isNumber) else { return nil }

        if fracPart.count <= 2 {
            return AmountToken(
                raw: token,
                digits: intPart + fracPart,
                shape: sep == "." ? .decimalDot : .decimalComma,
                separator: sep,
                digitsAfterSeparator: fracPart.count,
                isNegative: negative
            )
        }
        if fracPart.count == 3 && intPart.count <= 3 {
            return AmountToken(
                raw: token,
                digits: intPart + fracPart,
                shape: .ambiguousGroup,
                separator: sep,
                digitsAfterSeparator: 3,
                isNegative: negative
            )
        }
        return AmountToken(
            raw: token,
            digits: intPart + fracPart,
            shape: .grouped,
            separator: sep,
            digitsAfterSeparator: nil,
            isNegative: negative
        )
    }

    private static func stripCurrencyPrefix(_ s: String) -> String {
        var t = s
        let prefixes = ["$", "€", "£", "Rp", "R$", "USD", "EUR"]
        for p in prefixes {
            if t.hasPrefix(p) {
                t = String(t.dropFirst(p.count))
                break
            }
        }
        if t.hasSuffix("€") {
            t = String(t.dropLast())
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    private static func looksLikeDateOrPhone(_ s: String) -> Bool {
        if s.contains("/") && s.filter(\.isNumber).count >= 4 { return true }
        if s.contains(":") && s.filter(\.isNumber).count >= 3 { return true }
        if s.contains("-") && s.filter(\.isNumber).count >= 7 { return true }
        if s.hasPrefix("#") { return true }
        return false
    }
}

enum NumberFormatInference {
    static func infer(from tokens: [AmountToken], preferred: NumberFormat? = nil) -> NumberFormat {
        var dot = 0
        var comma = 0
        var groupDot = 0
        var groupComma = 0

        for token in tokens {
            switch token.shape {
            case .decimalDot:
                dot += (token.digitsAfterSeparator ?? 0) <= 2 ? 2 : 1
            case .decimalComma:
                comma += (token.digitsAfterSeparator ?? 0) <= 2 ? 2 : 1
            case .ambiguousGroup, .grouped:
                if token.separator == "." { groupDot += 1 } else { groupComma += 1 }
            case .integer:
                break
            }
        }

        if dot + comma > 0 {
            if dot >= comma {
                return NumberFormat(decimalSeparator: ".", groupSeparator: ",", fractionDigits: 2)
            }
            return NumberFormat(decimalSeparator: ",", groupSeparator: ".", fractionDigits: 2)
        }
        if groupDot + groupComma > 0 {
            if groupDot >= groupComma {
                return NumberFormat(decimalSeparator: ",", groupSeparator: ".", fractionDigits: 0, isGuessed: true)
            }
            return NumberFormat(decimalSeparator: ".", groupSeparator: ",", fractionDigits: 0, isGuessed: true)
        }
        if preferred == nil,
           tokens.contains(where: { $0.shape == .integer && $0.digits.count >= 4 }) {
            return NumberFormat(decimalSeparator: ".", groupSeparator: ",", fractionDigits: 0, isGuessed: true)
        }
        return preferred ?? .usdCents
    }

    static func minorUnits(_ token: AmountToken, format: NumberFormat) -> Int? {
        let sign = token.isNegative ? -1 : 1
        switch token.shape {
        case .integer:
            guard let value = Int(token.digits) else { return nil }
            if format.fractionDigits == 2 {
                if token.digits.count >= 4 { return nil }
                return sign * value * 100
            }
            return sign * value

        case .decimalDot, .decimalComma:
            let sep = token.separator!
            if sep != format.decimalSeparator { return nil }
            guard let frac = token.digitsAfterSeparator else { return nil }
            if frac != format.fractionDigits && format.fractionDigits == 2 && frac <= 2 {
                let padded = token.digits.padding(
                    toLength: token.digits.count + (format.fractionDigits - frac),
                    withPad: "0",
                    startingAt: 0
                )
                return parseDecimalDigits(padded, fractionDigits: format.fractionDigits, sign: sign)
            }
            return parseDecimalDigits(token.digits, fractionDigits: format.fractionDigits, sign: sign)

        case .ambiguousGroup, .grouped:
            let sep = token.separator!
            if format.fractionDigits == 0 && sep == format.groupSeparator {
                guard let value = Int(token.digits) else { return nil }
                return sign * value
            }
            if format.fractionDigits == 2 {
                if sep == format.decimalSeparator,
                   let frac = token.digitsAfterSeparator,
                   frac <= 2 {
                    return parseDecimalDigits(token.digits, fractionDigits: format.fractionDigits, sign: sign)
                }
            }
            return nil
        }
    }

    private static func parseDecimalDigits(_ digits: String, fractionDigits: Int, sign: Int) -> Int? {
        guard fractionDigits > 0 else { return Int(digits).map { sign * $0 } }
        guard digits.count > fractionDigits else { return nil }
        let split = digits.count - fractionDigits
        let whole = digits.prefix(split)
        let frac = digits.suffix(fractionDigits)
        guard let w = Int(whole), let f = Int(frac) else { return nil }
        return sign * (w * 100 + f)
    }
}
