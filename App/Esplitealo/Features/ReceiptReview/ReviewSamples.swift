import EsplitealoCore
import Foundation

/// A scan as the parser hands it over: the mockups' Fonda Doña Lola receipt where the flan was read as $19.00
/// instead of $9.00, so the row is flagged and the items do not add up to the printed subtotal. For previews,
/// snapshot tests and the UI-test fixture; `SampleBill` has the same receipt already fixed.
enum ReviewSamples {
    /// The flan, the eighth item of `SampleBill`.
    static let flanID = UUID(uuidString: "10000000-0000-0000-0000-000000000008")!

    static func parsedDraft() -> ReceiptDraft {
        var draft = SampleBill.scannedDraft()
        draft.items[7] = DraftItem(
            id: flanID,
            name: "Flan para compartir",
            quantity: 1,
            lineTotal: DraftAmount(minorUnits: 1900, needsAttention: true),
            flags: [.needsReview]
        )
        return draft
    }

    static func parsedSession() -> BillSession {
        var session = SampleBill.scanned()
        session.applyDraft(parsedDraft())
        return session
    }

    /// The warning for the flan, and for a stray "5" with no row name.
    static let unreadableFlanWarningID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let strayPriceWarningID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!

    /// A scan where the flan was printed "9,00" on a receipt that otherwise uses ".", so the parser could not read the
    /// price and left the row out, and a stray "5" had no name beside it. The receipt does not add up (the printed
    /// subtotal still counts the flan) and both readings are warnings. For previews, the UI-test fixture (`unsure`).
    static func unsureDraft() -> ReceiptDraft {
        var draft = SampleBill.scannedDraft()
        draft.items.removeAll { $0.id == flanID }
        draft.warnings = [
            ReceiptWarning(
                id: unreadableFlanWarningID,
                issue: .unparsedPriceRow("9,00"),
                rowLabel: "Flan para compartir"
            ),
            ReceiptWarning(id: strayPriceWarningID, issue: .unparsedPriceRow("5")),
        ]
        return draft
    }

    static func unsureSession() -> BillSession {
        var session = SampleBill.scanned()
        session.applyDraft(unsureDraft())
        return session
    }
}
