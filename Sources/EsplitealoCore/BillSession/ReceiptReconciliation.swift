import Foundation

public enum ReceiptReconciliationIssue: Equatable, Sendable {
    case itemsDoNotMatchSubtotal(itemsSum: Int, printed: Int)
    case totalsDoNotAddUp(expected: Int, printed: Int)
}

public struct ReceiptReconciliation: Equatable, Sendable {
    public var reconciles: Bool
    public var issues: [ReceiptReconciliationIssue]

    public var primaryIssue: ReceiptReconciliationIssue? { issues.first }
}

enum ReceiptReconciliationEngine {
    static func compute(
        items: [DraftItem],
        adjustments: [DraftAdjustment],
        subtotal: DraftAmount?,
        tax: DraftAmount?,
        tip: DraftAmount?,
        total: DraftAmount?
    ) -> ReceiptReconciliation {
        let itemsSum = items.reduce(0) { $0 + $1.lineTotal.minorUnits }
        let adjustmentsSum = adjustments.reduce(0) { $0 + $1.amount.minorUnits }
        let netItemsSum = itemsSum + adjustmentsSum
        var issues: [ReceiptReconciliationIssue] = []
        var reconciles = false

        if let sub = subtotal {
            if netItemsSum == sub.minorUnits {
                reconciles = true
            } else {
                issues.append(.itemsDoNotMatchSubtotal(itemsSum: netItemsSum, printed: sub.minorUnits))
            }
        } else if let tot = total {
            let taxVal = tax?.minorUnits ?? 0
            let tipVal = tip?.minorUnits ?? 0
            let expected = tot.minorUnits - taxVal - tipVal
            if netItemsSum == expected {
                reconciles = true
            } else {
                issues.append(.itemsDoNotMatchSubtotal(itemsSum: netItemsSum, printed: expected))
            }
        }

        if let sub = subtotal, let tot = total {
            let taxVal = tax?.minorUnits ?? 0
            let tipVal = tip?.minorUnits ?? 0
            let expected = sub.minorUnits + taxVal + tipVal
            if expected != tot.minorUnits {
                issues.append(.totalsDoNotAddUp(expected: expected, printed: tot.minorUnits))
                reconciles = false
            }
        }

        return ReceiptReconciliation(reconciles: reconciles, issues: issues)
    }
}
