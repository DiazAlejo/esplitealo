import XCTest
@testable import EsplitealoCore
import EsplitealoTestSupport

/// The warnings the parser raised stay with the bill: building a session, editing the receipt and saving it never
/// drop them. Only the user retires one, by fixing the row or by accepting it.
final class BillSessionWarningTests: XCTestCase {
    private let parser = ReceiptParser()

    private func scannedDraft() -> ReceiptDraft {
        parser.parse(RecognizedTextTestBuilder.fromRowTexts([
            "Coffee 3.50", "Tostada 2.25", "Soda 3,5", "Subtotal 5.75", "Total 5.75",
        ]))
    }

    private func warning(_ text: String, itemID: UUID? = nil) -> ReceiptWarning {
        ReceiptWarning(issue: .unparsedPriceRow(text), rowLabel: "Soda", itemID: itemID)
    }

    // MARK: Carried into the session

    func testParserWarningsReachTheBillSession() {
        let draft = scannedDraft()
        XCTAssertEqual(draft.warnings.count, 1)
        let session = BillSession(draft: draft)
        XCTAssertEqual(session.draft.warnings, draft.warnings, "building a session used to drop every parser issue")
        XCTAssertEqual(session.draft.activeWarnings.count, 1)
    }

    func testReconcilingKeepsTheWarnings() {
        let draft = ReceiptDraft(warnings: [warning("3,5")])
        let reconciled = ReceiptDraftEditing.reconcile(draft)
        XCTAssertEqual(reconciled.warnings, draft.warnings)
    }

    func testEditingTheReceiptKeepsTheWarnings() {
        var session = BillSession(draft: scannedDraft())
        let before = session.draft.warnings
        session.applyDraft(ReceiptDraftEditing.addItem(to: session.draft, name: "Soda", unitPriceCents: 350, quantity: 1))
        session.applyDraft(ReceiptDraftEditing.setTotal(session.draft, cents: 925))
        session.applyDraft(ReceiptDraftEditing.setSubtotal(session.draft, cents: 925))
        XCTAssertEqual(session.draft.warnings, before)
    }

    // MARK: Dismissing

    func testDismissingRetiresOnlyThatWarningAndKeepsTheRecord() {
        let first = warning("3,5")
        let second = warning("4,5")
        let draft = ReceiptDraftEditing.dismissWarning(in: ReceiptDraft(warnings: [first, second]), id: first.id)
        XCTAssertEqual(draft.warnings.count, 2, "a dismissed warning is kept, not deleted")
        XCTAssertEqual(draft.warnings.map(\.isDismissed), [true, false])
        XCTAssertEqual(draft.activeWarnings.map(\.id), [second.id])
    }

    func testDismissingAnUnknownWarningChangesNothing() {
        let draft = ReceiptDraft(warnings: [warning("3,5")])
        XCTAssertEqual(ReceiptDraftEditing.dismissWarning(in: draft, id: UUID()), draft)
    }

    func testDismissingTheWarningsOfAnItem() {
        let item = DraftItem(name: "Soda", lineTotal: DraftAmount(minorUnits: 0, needsAttention: true))
        let linked = warning("3,5", itemID: item.id)
        let other = warning("4,5")
        let draft = ReceiptDraft(items: [item], warnings: [linked, other])
        let result = ReceiptDraftEditing.dismissWarnings(in: draft, forItem: item.id)
        XCTAssertEqual(result.warnings.map(\.isDismissed), [true, false])
    }

    func testDeletingAnItemRetiresItsWarnings() {
        let item = DraftItem(name: "Soda", lineTotal: DraftAmount(minorUnits: 0, needsAttention: true))
        let draft = ReceiptDraft(items: [item], warnings: [warning("3,5", itemID: item.id), warning("4,5")])
        let result = ReceiptDraftEditing.deleteItem(in: draft, itemID: item.id)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.warnings.map(\.isDismissed), [true, false])
    }

    // MARK: Saved with the bill

    func testWarningsSurviveTheDraftStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("esplitealo-warning-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileBillDraftStore(directory: directory)
        var session = BillSession(draft: scannedDraft())
        session.applyDraft(ReceiptDraftEditing.dismissWarning(in: session.draft, id: session.draft.warnings[0].id))
        try store.save(session)
        let restored = try XCTUnwrap(try store.load())
        XCTAssertEqual(restored, session)
        XCTAssertEqual(restored.draft.warnings.map(\.isDismissed), [true])
    }
}
