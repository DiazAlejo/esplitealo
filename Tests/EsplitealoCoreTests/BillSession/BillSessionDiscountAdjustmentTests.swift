import XCTest
@testable import EsplitealoCore

final class BillSessionDiscountAdjustmentTests: XCTestCase {
    private func discountDraft() -> ReceiptDraft {
        var draft = ReceiptDraft(
            items: [DraftItem(name: "Plate", quantity: 1, lineTotal: DraftAmount(minorUnits: 3000))],
            subtotal: DraftAmount(minorUnits: 2500),
            tax: DraftAmount(minorUnits: 200),
            total: DraftAmount(minorUnits: 2700),
            adjustments: [DraftAdjustment(label: "Descuento", amount: DraftAmount(minorUnits: -500))]
        )
        return ReceiptDraftEditing.reconcile(draft)
    }

    private func discountedSession() -> BillSession {
        let alex = Participant(name: "Alex", orderIndex: 0)
        let draft = discountDraft()
        let item = draft.items[0]
        return BillSession(
            draft: draft,
            participants: [alex],
            assignments: [ItemAssignment(itemID: item.id, unitIndex: 0, participantIDs: [alex.id])],
            tip: .percentage(percent: 0, basis: .preTaxSubtotal)
        )
    }

    func testReconciledDiscountDraftBlocksWithExplicitReason() {
        let session = discountedSession()
        XCTAssertTrue(session.draft.reconciliation.reconciles)
        XCTAssertEqual(session.netItemsSubtotalCents, 2500)
        XCTAssertEqual(session.derivedBillTotalCents, 2700)
        XCTAssertFalse(session.canShare)
        XCTAssertEqual(session.shareBlockReason, .discountNeedsManualAdjustment)
        XCTAssertNotEqual(session.shareBlockReason, .receiptMismatch)
        XCTAssertEqual(session.phase, .totals)
    }

    func testManualNetDiscountIntoItemsUnblocksSharing() {
        let alex = Participant(name: "Alex", orderIndex: 0)
        var draft = discountDraft()
        let itemID = draft.items[0].id
        var session = BillSession(
            draft: draft,
            participants: [alex],
            assignments: [ItemAssignment(itemID: itemID, unitIndex: 0, participantIDs: [alex.id])],
            tip: .percentage(percent: 0, basis: .preTaxSubtotal)
        )
        draft = ReceiptDraftEditing.updateItem(
            in: draft,
            itemID: itemID,
            name: "Plate",
            unitPriceCents: 2500,
            quantity: 1
        )
        draft.adjustments = []
        draft = ReceiptDraftEditing.reconcile(draft)
        session.draft = draft
        XCTAssertTrue(session.canShare)
        XCTAssertNil(session.shareBlockReason)
        XCTAssertEqual(session.phase, .ready)
    }

    func testShareTextEmptyWhenDiscountNeedsManualAdjustment() {
        let session = discountedSession()
        XCTAssertEqual(ShareSummaryBuilder.build(for: session, language: .es), "")
        XCTAssertEqual(ShareSummaryBuilder.build(for: session, language: .en), "")
    }

    func testTipBasisUsesNetSubtotal() {
        var session = discountedSession()
        session.tip = .percentage(percent: 20, basis: .preTaxSubtotal)
        XCTAssertEqual(session.sessionTipCents, 500)
    }
}
