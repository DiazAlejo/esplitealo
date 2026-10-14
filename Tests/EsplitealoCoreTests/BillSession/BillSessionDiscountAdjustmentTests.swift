import XCTest
@testable import EsplitealoCore

final class BillSessionDiscountAdjustmentTests: XCTestCase {
    private func discountedSession() -> BillSession {
        let alex = Participant(name: "Alex", orderIndex: 0)
        let item = DraftItem(name: "A", quantity: 1, lineTotal: DraftAmount(minorUnits: 3000))
        let draft = ReceiptDraft(
            items: [item],
            subtotal: DraftAmount(minorUnits: 2500),
            tax: DraftAmount(minorUnits: 200),
            total: DraftAmount(minorUnits: 2700),
            adjustments: [DraftAdjustment(label: "Descuento", amount: DraftAmount(minorUnits: -500))]
        )
        return BillSession(
            draft: draft,
            participants: [alex],
            assignments: [ItemAssignment(itemID: item.id, unitIndex: 0, participantIDs: [alex.id])],
            tip: .percentage(percent: 0, basis: .preTaxSubtotal)
        )
    }

    func testDiscountedReceiptReconcilesButIsBlockedForSharing() {
        let session = discountedSession()
        XCTAssertTrue(session.draft.reconciliation.reconciles)
        XCTAssertEqual(session.netItemsSubtotalCents, 2500)
        XCTAssertEqual(session.derivedBillTotalCents, 2700)
        XCTAssertFalse(session.canShare)
        XCTAssertEqual(session.shareBlockReason, .discountNeedsManualAdjustment)
        XCTAssertEqual(ShareSummaryBuilder.build(for: session, language: .en), "")
    }

    func testTipBasisUsesNetSubtotal() {
        var session = discountedSession()
        session.tip = .percentage(percent: 20, basis: .preTaxSubtotal)
        XCTAssertEqual(session.sessionTipCents, 500)
    }
}
