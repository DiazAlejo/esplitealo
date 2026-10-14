import XCTest
@testable import EsplitealoCore

final class BillSessionTotalsTests: XCTestCase {
    func testDefaultTipZeroWhenReceiptHasServiceCharge() {
        var session = BillSession.sampleWithServiceCharge()
        XCTAssertEqual(session.tip, .percentage(percent: 0, basis: .preTaxSubtotal))
    }

    func testPhaseMismatchBlocksShareButAllowsContinueAfterAcknowledge() {
        var session = BillSession.sampleMismatch()
        XCTAssertEqual(session.phase, .mismatch)
        XCTAssertFalse(session.canShare)
        session.acknowledgeMismatch()
        XCTAssertEqual(session.phase, .needsAssignment)
        XCTAssertEqual(session.shareBlockReason, .unassignedItems)
        XCTAssertFalse(session.canShare)
    }

    func testPhaseReadyWhenSettledAndReconciled() {
        var session = BillSession.sampleReadyToShare()
        XCTAssertEqual(session.phase, .ready)
        XCTAssertTrue(session.canShare)
        let split = session.splitResult
        XCTAssertTrue(split.isSettled)
        XCTAssertTrue(split.totalsMatch)
        XCTAssertEqual(split.shares.map(\.amountOwedCents).reduce(0, +), 13_000)
    }

    func testUnassignedBlocksReady() {
        var session = BillSession.sampleReadyToShare()
        let item = session.draft.items[0]
        session.clearUnitAssignment(itemID: item.id, unitIndex: 0)
        XCTAssertEqual(session.phase, .needsAssignment)
        XCTAssertFalse(session.canShare)
    }

    func testCustomTipAndPostTaxBasis() {
        var session = BillSession.sampleReadyToShare()
        session.tip = .percentage(percent: 20, basis: .postTaxTotal)
        let tip = session.sessionTipCents
        XCTAssertEqual(tip, 2200)
    }
}
