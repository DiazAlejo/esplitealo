import XCTest
@testable import EsplitealoCore

final class BillSessionReviewFixTests: XCTestCase {
    // review-1 (a): printed tip on receipt, no service charge
    func testPrintedReceiptTipAllocatedAndCanShare() {
        let alex = Participant(name: "Alex", orderIndex: 0)
        let sam = Participant(name: "Sam", orderIndex: 1)
        let alexItem = DraftItem(name: "A", quantity: 1, lineTotal: DraftAmount(minorUnits: 6000))
        let samItem = DraftItem(name: "B", quantity: 1, lineTotal: DraftAmount(minorUnits: 4000))
        var draft = ReceiptDraft(
            items: [alexItem, samItem],
            subtotal: DraftAmount(minorUnits: 10_000),
            tax: DraftAmount(minorUnits: 1000),
            tip: DraftAmount(minorUnits: 2000),
            total: DraftAmount(minorUnits: 13_000)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        var session = BillSession(
            draft: draft,
            participants: [alex, sam],
            assignments: [
                ItemAssignment(itemID: alexItem.id, unitIndex: 0, participantIDs: [alex.id]),
                ItemAssignment(itemID: samItem.id, unitIndex: 0, participantIDs: [sam.id]),
            ]
        )
        XCTAssertEqual(session.tip, .percentage(percent: 0, basis: .preTaxSubtotal))
        XCTAssertTrue(session.canShare)
        XCTAssertEqual(session.confirmedBillTotalCents, 13_000)
        let sum = session.personBreakdowns.map(\.totalOwedCents).reduce(0, +)
        XCTAssertEqual(sum, 13_000)
    }

    // review-1 (b): subtotal present, no printed total
    func testMissingPrintedTotalIsExplicitAndBlocksShare() {
        var draft = ReceiptDraft(
            items: [DraftItem(name: "A", quantity: 1, lineTotal: DraftAmount(minorUnits: 500))],
            subtotal: DraftAmount(minorUnits: 500)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        var session = BillSession(draft: draft)
        _ = session.addParticipant(name: "Alex")
        XCTAssertNil(session.printedReceiptTotalCents)
        XCTAssertEqual(session.phase, .missingPrintedTotal)
        XCTAssertEqual(session.shareBlockReason, .missingPrintedTotal)
        XCTAssertFalse(session.canShare)
    }

    func testShareHeaderAndClosingSumAgreeWithPrintedTipReceipt() {
        var session = BillSession.sampleReadyToShareWithPrintedTip()
        let text = ShareSummaryBuilder.build(for: session, language: .en)
        XCTAssertTrue(text.contains("Bill $130.00 + "))
        XCTAssertTrue(text.contains("Adds up to $130.00."))
        let sum = session.personBreakdowns.map(\.totalOwedCents).reduce(0, +)
        XCTAssertEqual(sum, session.confirmedBillTotalCents)
    }

    // review-2
    func testAcknowledgedMismatchAssignedReachesTotalsWithShareBlocked() {
        var session = BillSession.sampleMismatchFullyAssigned()
        XCTAssertEqual(session.phase, .mismatch)
        session.acknowledgeMismatch()
        XCTAssertNotEqual(session.phase, .mismatch)
        XCTAssertEqual(session.phase, .totals)
        XCTAssertEqual(session.shareBlockReason, .receiptMismatch)
        XCTAssertFalse(session.canShare)
    }

    func testAcknowledgedMismatchWithUnassignedStillNeedsAssignment() {
        var session = BillSession.sampleMismatch()
        session.acknowledgeMismatch()
        XCTAssertEqual(session.phase, .needsAssignment)
        XCTAssertEqual(session.shareBlockReason, .unassignedItems)
    }

    func testFixingMismatchAfterAcknowledgeUnblocksShare() {
        var session = BillSession.sampleMismatchFullyAssigned()
        session.acknowledgeMismatch()
        session.draft = ReceiptDraftEditing.setTotal(session.draft, cents: 500)
        session.draft = ReceiptDraftEditing.setSubtotal(session.draft, cents: 500)
        XCTAssertTrue(session.canShare)
        XCTAssertNil(session.shareBlockReason)
        XCTAssertEqual(session.phase, .ready)
    }
}
