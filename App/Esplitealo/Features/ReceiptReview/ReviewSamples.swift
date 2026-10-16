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
}
