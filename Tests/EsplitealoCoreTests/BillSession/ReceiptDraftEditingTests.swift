import XCTest
@testable import EsplitealoCore

final class ReceiptDraftEditingTests: XCTestCase {
    func testAddEditDeleteItemRecomputesReconciliation() {
        var draft = ReceiptDraft()
        draft = ReceiptDraftEditing.addItem(
            to: draft,
            name: "Coffee",
            unitPriceCents: 350,
            quantity: 2
        )
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(draft.items[0].lineTotal.minorUnits, 700)
        XCTAssertEqual(draft.items[0].quantity, 2)

        let itemID = draft.items[0].id
        draft = ReceiptDraftEditing.updateItem(
            in: draft,
            itemID: itemID,
            name: "Café",
            unitPriceCents: 400,
            quantity: 2
        )
        XCTAssertEqual(draft.items[0].name, "Café")
        XCTAssertEqual(draft.items[0].lineTotal.minorUnits, 800)

        draft = ReceiptDraftEditing.setSubtotal(draft, cents: 800)
        draft = ReceiptDraftEditing.setTax(draft, cents: 92)
        draft = ReceiptDraftEditing.setTotal(draft, cents: 892)
        XCTAssertTrue(draft.reconciliation.reconciles)

        draft = ReceiptDraftEditing.deleteItem(in: draft, itemID: itemID)
        XCTAssertTrue(draft.items.isEmpty)
        XCTAssertFalse(draft.reconciliation.reconciles)
    }

    func testParserFlagsSurviveEdits() {
        var draft = ReceiptDraft(
            items: [
                DraftItem(
                    name: "Flan",
                    quantity: 1,
                    lineTotal: DraftAmount(minorUnits: 800),
                    flags: [.needsReview, .formatGuessed]
                ),
            ]
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        let id = draft.items[0].id
        draft = ReceiptDraftEditing.updateItem(
            in: draft,
            itemID: id,
            name: "Flan",
            unitPriceCents: 900,
            quantity: 1
        )
        XCTAssertTrue(draft.items[0].flags.contains(.needsReview))
        XCTAssertTrue(draft.items[0].flags.contains(.formatGuessed))
    }

    func testReceiptTotalNeverAutoAdjustedToMatchItems() {
        var draft = ReceiptDraft(
            items: [
                DraftItem(name: "A", quantity: 1, lineTotal: DraftAmount(minorUnits: 500)),
            ],
            subtotal: DraftAmount(minorUnits: 500),
            total: DraftAmount(minorUnits: 999)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        XCTAssertEqual(draft.total?.minorUnits, 999)
        XCTAssertFalse(draft.reconciliation.reconciles)
        if case let .totalsDoNotAddUp(expected, printed) = draft.reconciliation.primaryIssue {
            XCTAssertEqual(expected, 500)
            XCTAssertEqual(printed, 999)
        } else {
            XCTFail("expected totals mismatch exposure")
        }
    }

    func testReconciliationViaTotalMinusTaxAndTipWhenSubtotalMissing() {
        var draft = ReceiptDraft(
            items: [
                DraftItem(name: "B", quantity: 1, lineTotal: DraftAmount(minorUnits: 1000)),
            ],
            tax: DraftAmount(minorUnits: 100),
            tip: DraftAmount(minorUnits: 200),
            total: DraftAmount(minorUnits: 1300)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        XCTAssertTrue(draft.reconciliation.reconciles)
    }
}
