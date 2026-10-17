import EsplitealoCore
import Foundation

/// Why a parsed bill differs from the ground truth. A receipt can have several.
public enum StressFailureCause: String, Codable, CaseIterable, Sendable {
    /// The scanner refused the image (too long, unreadable, no text).
    case scanRejected
    case noItemsParsed
    /// Printed items the parser did not return.
    case itemMissing
    /// Items the parser returned that are not on the receipt (header, count line, payment text).
    case itemExtra
    /// Same number of items but a different set of line totals.
    case itemPriceWrong
    case itemQuantityWrong
    /// A discount or negative line missing, extra, or with a different amount.
    case adjustmentWrong
    case subtotalMissing
    case subtotalWrong
    case taxMissing
    case taxWrong
    case tipMissing
    case tipWrong
    case totalMissing
    case totalWrong
}

public struct BillComparison: Codable, Equatable, Sendable {
    /// Items (line total and quantity), adjustments, subtotal, tax, tip and total all equal the truth to the cent.
    public var exact: Bool
    /// Same as `exact`, ignoring item quantities.
    public var amountsExact: Bool
    public var causes: [StressFailureCause]
    /// One line per mismatch, for failure artifacts.
    public var details: [String]
}

public enum BillExactness {
    public static func compare(draft: ReceiptDraft, truth: StressBillTruth) -> BillComparison {
        var causes: [StressFailureCause] = []
        var details: [String] = []

        // Items: compare line totals as multisets, then quantities of the matched pairs.
        let parsedTotals = draft.items.map(\.lineTotal.minorUnits).sorted()
        let truthTotals = truth.items.map(\.lineTotalMinor).sorted()
        let missing = multisetDifference(truthTotals, parsedTotals)
        let extra = multisetDifference(parsedTotals, truthTotals)
        if draft.items.isEmpty, !truth.items.isEmpty {
            causes.append(.noItemsParsed)
            details.append("no items parsed, expected \(truthTotals)")
        } else if !missing.isEmpty || !extra.isEmpty {
            if missing.count == extra.count {
                causes.append(.itemPriceWrong)
            } else if missing.count > extra.count {
                causes.append(.itemMissing)
            } else {
                causes.append(.itemExtra)
            }
            var remainingExtra = extra
            var extraNames: [String] = []
            for item in draft.items {
                if let index = remainingExtra.firstIndex(of: item.lineTotal.minorUnits) {
                    remainingExtra.remove(at: index)
                    extraNames.append("\"\(item.name)\"")
                }
            }
            var remainingMissing = missing
            var missingNames: [String] = []
            for item in truth.items {
                if let index = remainingMissing.firstIndex(of: item.lineTotalMinor) {
                    remainingMissing.remove(at: index)
                    missingNames.append("\"\(item.name)\"")
                }
            }
            details.append(
                "items: missing \(format(missing)) \(missingNames.joined(separator: ", ")), extra \(format(extra)) \(extraNames.joined(separator: ", "))"
            )
        }

        var quantitiesExact = true
        if missing.isEmpty, extra.isEmpty {
            var remaining = truth.items
            for item in draft.items {
                guard let index = remaining.firstIndex(where: {
                    $0.lineTotalMinor == item.lineTotal.minorUnits && $0.quantity == item.quantity
                }) else {
                    quantitiesExact = false
                    if let other = remaining.firstIndex(where: { $0.lineTotalMinor == item.lineTotal.minorUnits }) {
                        details.append(
                            "quantity of \(format([item.lineTotal.minorUnits])): parsed \(item.quantity), expected \(remaining[other].quantity)"
                        )
                        remaining.remove(at: other)
                    }
                    continue
                }
                remaining.remove(at: index)
            }
            if !quantitiesExact { causes.append(.itemQuantityWrong) }
        }

        let parsedAdjustments = draft.adjustments.map(\.amount.minorUnits).sorted()
        let truthAdjustments = truth.adjustmentsMinor.sorted()
        if parsedAdjustments != truthAdjustments {
            causes.append(.adjustmentWrong)
            details.append("adjustments: parsed \(format(parsedAdjustments)), expected \(format(truthAdjustments))")
        }

        func check(
            _ parsed: Int?, _ expected: Int, missing: StressFailureCause, wrong: StressFailureCause, label: String
        ) {
            guard parsed != expected else { return }
            causes.append(parsed == nil ? missing : wrong)
            details.append("\(label): parsed \(parsed.map { format([$0]) } ?? "none"), expected \(format([expected]))")
        }
        check(draft.subtotal?.minorUnits, truth.subtotalMinor, missing: .subtotalMissing, wrong: .subtotalWrong, label: "subtotal")
        // A receipt without tax or tip lines is expected to parse without them, or with zero.
        let parsedTax = draft.tax?.minorUnits
        if truth.taxLinesMinor.isEmpty {
            if let parsedTax, parsedTax != 0 {
                causes.append(.taxWrong)
                details.append("tax: parsed \(format([parsedTax])), expected none")
            }
        } else {
            check(parsedTax, truth.taxMinor, missing: .taxMissing, wrong: .taxWrong, label: "tax")
        }
        let parsedTip = draft.tip?.minorUnits
        if truth.tipMinor == 0 {
            if let parsedTip, parsedTip != 0 {
                causes.append(.tipWrong)
                details.append("tip: parsed \(format([parsedTip])), expected none")
            }
        } else {
            check(parsedTip, truth.tipMinor, missing: .tipMissing, wrong: .tipWrong, label: "tip")
        }
        check(draft.total?.minorUnits, truth.totalMinor, missing: .totalMissing, wrong: .totalWrong, label: "total")

        let amountsExact = causes.filter { $0 != .itemQuantityWrong }.isEmpty
        return BillComparison(exact: causes.isEmpty, amountsExact: amountsExact, causes: causes, details: details)
    }

    /// True when the draft tells the user something may be wrong: it does not reconcile, carries an issue, or has an
    /// item or amount marked for review. A wrong bill that is not flagged is a silent failure.
    public static func isFlagged(_ draft: ReceiptDraft) -> Bool {
        if !draft.reconciles || !draft.issues.isEmpty { return true }
        let amounts = [draft.subtotal, draft.tax, draft.tip, draft.total].compactMap { $0 }
            + draft.items.map(\.lineTotal) + draft.adjustments.map(\.amount)
        if amounts.contains(where: \.needsAttention) { return true }
        let reviewFlags: Set<ItemFlag> = [.needsReview, .quantityMismatch, .zeroPrice, .formatGuessed]
        return draft.items.contains { !$0.flags.isDisjoint(with: reviewFlags) }
    }

    /// Elements of `a` left after removing one match for each element of `b`.
    static func multisetDifference(_ a: [Int], _ b: [Int]) -> [Int] {
        var remaining = b
        var result: [Int] = []
        for value in a {
            if let index = remaining.firstIndex(of: value) {
                remaining.remove(at: index)
            } else {
                result.append(value)
            }
        }
        return result
    }

    private static func format(_ values: [Int]) -> String {
        "[" + values.map { StressMoney.format($0, dollar: false) }.joined(separator: ", ") + "]"
    }
}
