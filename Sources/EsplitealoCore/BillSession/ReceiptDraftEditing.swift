import Foundation

public enum ReceiptDraftEditing {
    public static func reconcile(_ draft: ReceiptDraft) -> ReceiptDraft {
        var copy = draft
        let reconciliation = ReceiptReconciliationEngine.compute(
            items: copy.items,
            adjustments: copy.adjustments,
            subtotal: copy.subtotal,
            tax: copy.tax,
            tip: copy.tip,
            total: copy.total
        )
        copy.reconciles = reconciliation.reconciles
        copy.issues = reconciliation.issues.map { issue in
            switch issue {
            case let .itemsDoNotMatchSubtotal(items, printed):
                .itemsDoNotMatchSubtotal(itemsSum: items, printed: printed)
            case let .totalsDoNotAddUp(expected, printed):
                .totalsDoNotAddUp(expected: expected, printed: printed)
            }
        }
        return copy
    }

    public static func addItem(
        to draft: ReceiptDraft,
        name: String,
        unitPriceCents: Int,
        quantity: Int
    ) -> ReceiptDraft {
        let q = max(1, quantity)
        let line = DraftItem(
            name: name,
            quantity: q,
            lineTotal: DraftAmount(minorUnits: unitPriceCents * q),
            unitPrice: DraftAmount(minorUnits: unitPriceCents)
        )
        var copy = draft
        copy.items.append(line)
        return reconcile(copy)
    }

    public static func updateItem(
        in draft: ReceiptDraft,
        itemID: UUID,
        name: String,
        unitPriceCents: Int,
        quantity: Int
    ) -> ReceiptDraft {
        var copy = draft
        guard let index = copy.items.firstIndex(where: { $0.id == itemID }) else { return draft }
        let q = max(1, quantity)
        var item = copy.items[index]
        item.name = name
        item.quantity = q
        item.lineTotal = DraftAmount(minorUnits: unitPriceCents * q, needsAttention: item.lineTotal.needsAttention)
        item.unitPrice = DraftAmount(minorUnits: unitPriceCents)
        copy.items[index] = item
        return reconcile(copy)
    }

    public static func deleteItem(in draft: ReceiptDraft, itemID: UUID) -> ReceiptDraft {
        var copy = draft
        copy.items.removeAll { $0.id == itemID }
        return reconcile(copy)
    }

    public static func setSubtotal(_ draft: ReceiptDraft, cents: Int?) -> ReceiptDraft {
        var copy = draft
        copy.subtotal = cents.map { DraftAmount(minorUnits: $0) }
        return reconcile(copy)
    }

    public static func setTax(_ draft: ReceiptDraft, cents: Int?) -> ReceiptDraft {
        var copy = draft
        copy.tax = cents.map { DraftAmount(minorUnits: $0) }
        return reconcile(copy)
    }

    public static func setReceiptTip(_ draft: ReceiptDraft, cents: Int?) -> ReceiptDraft {
        var copy = draft
        copy.tip = cents.map { DraftAmount(minorUnits: $0) }
        return reconcile(copy)
    }

    public static func setTotal(_ draft: ReceiptDraft, cents: Int?) -> ReceiptDraft {
        var copy = draft
        copy.total = cents.map { DraftAmount(minorUnits: $0) }
        return reconcile(copy)
    }
}

extension ReceiptDraft {
    public var reconciliation: ReceiptReconciliation {
        ReceiptReconciliationEngine.compute(
            items: items,
            adjustments: adjustments,
            subtotal: subtotal,
            tax: tax,
            tip: tip,
            total: total
        )
    }
}
