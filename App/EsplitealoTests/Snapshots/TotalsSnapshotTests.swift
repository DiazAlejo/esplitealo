import EsplitealoCore
import SwiftUI
import Testing
@testable import Esplitealo

/// The Totals screen in its states (reconciled, unassigned items, a receipt mismatch, a service charge, a custom tip)
/// plus the share sheet and the success moment. Each is rendered in light and dark, Spanish and English, and at the
/// largest Dynamic Type size.
@MainActor
struct TotalsSnapshotTests {
    private func store(_ session: BillSession) -> BillStore {
        let store = BillStore(draftStore: RecordingDraftStore(), clock: ManualClock())
        store.startNewBill(draft: session.draft)
        store.update { $0 = session }
        return store
    }

    private func screen(_ session: BillSession) -> some View {
        NavigationStack { TotalsView() }
            .environment(store(session))
            .environment(AppRouter())
    }

    @Test func reconciled() {
        assertDesignSnapshot(screen(SampleBill.complete()), named: "reconciled", fixedHeight: 844)
    }

    @Test func reconciledWholeScroll() {
        assertDesignSnapshot(
            screen(SampleBill.complete()),
            named: "reconciled-full",
            variants: [.lightSpanish, .darkSpanish, .lightEnglish],
            fixedHeight: 1900
        )
    }

    @Test func unassignedItemsBlockTheSplit() {
        assertDesignSnapshot(screen(SampleBill.midway()), named: "unassigned", fixedHeight: 844)
    }

    @Test func aConfirmedMismatchStillBlocksSharing() {
        assertDesignSnapshot(screen(TotalsSamples.mismatch()), named: "mismatch", fixedHeight: 844)
    }

    @Test func serviceChargeStartsTheTipAtZero() {
        assertDesignSnapshot(screen(TotalsSamples.serviceCharge()), named: "service", fixedHeight: 844)
    }

    @Test func customTipAfterTax() {
        var session = SampleBill.complete()
        session.tip = .custom(cents: 1850)
        assertDesignSnapshot(screen(session), named: "custom-tip", fixedHeight: 844)
    }

    @Test func percentageAfterTax() {
        var session = SampleBill.complete()
        session.tip = .percentage(percent: 18, basis: .postTaxTotal)
        assertDesignSnapshot(screen(session), named: "post-tax", fixedHeight: 844)
    }

    @Test func shareSheetShowsTheSummaryInSpanishAndEnglish() {
        let model = TotalsViewModel(store: store(SampleBill.complete()))
        assertDesignSnapshot(ShareSheetContent(model: model, onCancel: {}), named: "share-sheet", fixedHeight: 780)
    }

    @Test func successMoment() {
        assertDesignSnapshot(ShareSuccessView(peopleCount: 4, totalCents: 13_282, onNewBill: {}, onBack: {}), named: "success", fixedHeight: 844)
    }
}
