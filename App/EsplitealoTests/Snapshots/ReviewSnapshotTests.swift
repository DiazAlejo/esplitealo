import EsplitealoCore
import SwiftUI
import Testing
@testable import Esplitealo

/// The Review receipt screen and its sheets, in both appearances and languages and at the largest type size.
/// The sheets are rendered on their own: a presented sheet is not part of the screen's view hierarchy.
@MainActor
struct ReviewSnapshotTests {
    private func store(_ session: BillSession?) -> BillStore {
        let store = BillStore(draftStore: RecordingDraftStore(), clock: ManualClock())
        if let session {
            store.startNewBill(draft: session.draft)
            store.update { $0 = session }
        }
        return store
    }

    private func screen(_ session: BillSession?) -> some View {
        NavigationStack { ReviewView() }
            .environment(store(session))
            .environment(AppRouter())
    }

    @Test func mismatchWithAFlaggedRow() {
        assertDesignSnapshot(screen(ReviewSamples.parsedSession()), named: "mismatch", fixedHeight: 844)
    }

    @Test func everythingAddsUp() {
        assertDesignSnapshot(screen(SampleBill.scanned()), named: "balanced", fixedHeight: 844)
    }

    @Test func noItemsYet() {
        assertDesignSnapshot(screen(BillSession(draft: ReceiptDraft())), named: "empty", fixedHeight: 844)
    }

    @Test func rowsWithSeveralUnitsAndAServiceCharge() {
        var draft = SampleBill.scannedDraft()
        draft.items[1] = DraftItem(
            id: draft.items[1].id, name: "Medalla", quantity: 3,
            lineTotal: DraftAmount(minorUnits: 1500), unitPrice: DraftAmount(minorUnits: 500)
        )
        draft.subtotal = DraftAmount(minorUnits: 11_100)
        draft.tip = DraftAmount(minorUnits: 1665)
        draft.total = DraftAmount(minorUnits: 11_100 + 1162 + 1665)
        assertDesignSnapshot(screen(BillSession(draft: draft)), named: "quantities-and-service", fixedHeight: 844)
    }

    @Test func parserDiscountRows() {
        var draft = SampleBill.scannedDraft()
        draft.adjustments = [DraftAdjustment(label: "Descuento", amount: DraftAmount(minorUnits: -500))]
        assertDesignSnapshot(screen(BillSession(draft: draft)), named: "adjustments", fixedHeight: 844)
    }

    @Test func editSheetForAFlaggedRow() {
        let model = ReceiptReviewModel(store: store(ReviewSamples.parsedSession()))
        assertDesignSnapshot(
            ItemEditorSheet(model: model, itemID: ReviewSamples.flanID, onClose: {}),
            named: "item-editor-flagged", fixedHeight: 560
        )
    }

    @Test func newItemSheet() {
        let model = ReceiptReviewModel(store: store(SampleBill.scanned()))
        assertDesignSnapshot(
            ItemEditorSheet(model: model, itemID: nil, onClose: {}),
            named: "item-editor-new", fixedHeight: 500
        )
    }

    @Test func receiptAmountSheet() {
        let model = ReceiptReviewModel(store: store(SampleBill.scanned()))
        assertDesignSnapshot(
            AmountEditorSheet(model: model, field: .total, onClose: {}),
            named: "amount-editor", fixedHeight: 380
        )
    }

    @Test func confirmationWhenTheNumbersDoNotMatch() {
        assertDesignSnapshot(
            MismatchConfirmationSheet(differenceCents: 1000, onFix: {}, onContinue: {}),
            named: "confirm-mismatch", fixedHeight: 340
        )
    }

    @Test func confirmationWhenTheTotalIsMissing() {
        assertDesignSnapshot(
            MismatchConfirmationSheet(differenceCents: nil, onFix: {}, onContinue: {}),
            named: "confirm-missing-total", fixedHeight: 340
        )
    }
}
