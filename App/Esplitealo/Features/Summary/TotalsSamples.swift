import EsplitealoCore
import Foundation

/// Bills for the Totals screen's previews, snapshot tests and UI-test fixtures, built on `SampleBill`.
enum TotalsSamples {
    /// Everything marked, but the flan was read as $19.00 instead of $9.00 and the user went on anyway: the items add up
    /// to $111.00 and the receipt's subtotal says $101.00.
    static func mismatch() -> BillSession {
        var session = SampleBill.complete()
        session.applyDraft(ReviewSamples.parsedDraft())
        session.acknowledgeMismatch()
        return session
    }

    /// Everything marked on a receipt that already has a $15.15 service charge: the tip starts at $0.00.
    static func serviceCharge() -> BillSession {
        var session = SampleBill.complete()
        var draft = session.draft
        draft.tip = DraftAmount(minorUnits: 1515)
        draft.total = DraftAmount(minorUnits: 12_777)
        session.applyDraft(draft)
        session.tip = .percentage(percent: 0, basis: .preTaxSubtotal)
        return session
    }
}
