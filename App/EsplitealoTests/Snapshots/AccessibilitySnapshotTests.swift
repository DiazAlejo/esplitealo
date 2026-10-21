import EsplitealoCore
import SwiftUI
import Testing
@testable import Esplitealo

/// Every screen and sheet at the sizes people with low vision use: xxxLarge and AX3 in light and dark, Spanish and
/// English, and AX5 (the largest) on a taller canvas so nothing below the fold hides a clipped line. Then the screens
/// on the smallest supported phone (iPhone SE, 375 x 667) at xxxLarge and in landscape. Look at the images: a recorded
/// reference proves the app renders that way, not that it renders well.
@MainActor
struct AccessibilitySnapshotTests {
    /// The accessibility matrix at the phone's height, and AX5 on a canvas twice as tall.
    private func snapshot(_ view: some View, _ name: String, height: CGFloat = 844, testName: String = #function) {
        assertDesignSnapshot(
            view, named: "a11y-\(name)",
            variants: SnapshotVariant.accessibilityMatrix.filter { $0.dynamicType != .accessibility5 },
            fixedHeight: height,
            testName: testName
        )
        assertDesignSnapshot(view, named: "a11y-\(name)", variants: [.ax5LightSpanish], fixedHeight: height * 2, testName: testName)
    }

    private func store(_ session: BillSession?) -> BillStore {
        let store = BillStore(draftStore: RecordingDraftStore(), clock: ManualClock())
        if let session {
            store.startNewBill(draft: session.draft)
            store.update { $0 = session }
        }
        return store
    }

    private func assignModel(_ session: BillSession) -> AssignViewModel {
        AssignViewModel(store: store(session))
    }

    // MARK: Home and capture

    @Test func home() {
        snapshot(NavigationStack { HomeView(animatesMascot: false) }.environment(AppRouter()).environment(BillStore.live(arguments: ["--uitesting"])).environment(ScanFlow.preview()), "home")
    }

    @Test func howItWorks() {
        snapshot(HowItWorksSheet(onDone: {}), "how-it-works", height: 700)
    }

    @Test func cameraDenied() {
        snapshot(NavigationStack { CaptureBlockedContent(block: .denied) }, "camera-denied")
    }

    @Test func reading() {
        snapshot(NavigationStack { ProcessingContent(messageIndex: 2, offersManualEntry: true, animates: false) }, "reading")
    }

    @Test func scanFailed() {
        snapshot(NavigationStack { ScanFailedContent(failure: .unreadable, source: .camera, animates: false) }, "scan-failed")
    }

    // MARK: Review

    @Test func review() {
        snapshot(NavigationStack { ReviewView() }.environment(store(ReviewSamples.parsedSession())).environment(AppRouter()), "review")
    }

    @Test func itemEditor() {
        let model = ReceiptReviewModel(store: store(ReviewSamples.parsedSession()))
        snapshot(ItemEditorSheet(model: model, itemID: ReviewSamples.flanID, onClose: {}), "item-editor", height: 560)
    }

    @Test func mismatchConfirmation() {
        snapshot(MismatchConfirmationSheet(differenceCents: 1000, onFix: {}, onContinue: {}), "confirm-mismatch", height: 420)
    }

    // MARK: People

    @Test func people() {
        snapshot(NavigationStack { PeopleView() }.environment(store(SampleBill.midway())).environment(AppRouter()), "people")
    }

    @Test func removePerson() throws {
        let store = store(SampleBill.midway())
        let model = PeopleViewModel(store: store)
        model.requestRemoval(id: store.session!.participants[1].id)
        let removal = try #require(model.pendingRemoval)
        snapshot(RemovePersonSheet(removal: removal, onKeep: {}, onRemove: {}), "remove-person", height: 420)
    }

    // MARK: Mark items

    @Test func markItems() {
        snapshot(NavigationStack { AssignScreen(model: assignModel(SampleBill.midway())) }.environment(AppRouter()), "mark")
    }

    @Test func markItemsWarning() {
        let model = assignModel(SampleBill.midway())
        _ = model.reviewSplit()
        snapshot(NavigationStack { AssignScreen(model: model) }.environment(AppRouter()), "mark-warning")
    }

    @Test func assignSheet() {
        let model = assignModel(AssignSamples.table())
        let surtido = AssignSamples.itemID(3)
        for number in 1 ... 3 { model.toggle(AssignSamples.personID(number), on: surtido) }
        model.tapRow(surtido)
        snapshot(AssignSheet(model: model), "assign-sheet", height: 700)
    }

    // MARK: Totals

    @Test func totals() {
        snapshot(NavigationStack { TotalsView() }.environment(store(SampleBill.complete())).environment(AppRouter()), "totals")
    }

    @Test func totalsBlocked() {
        snapshot(NavigationStack { TotalsView() }.environment(store(TotalsSamples.mismatch())).environment(AppRouter()), "totals-blocked")
    }

    @Test func shareSheet() {
        let model = TotalsViewModel(store: store(SampleBill.complete()))
        snapshot(ShareSheetContent(model: model, onCancel: {}), "share-sheet", height: 780)
    }

    @Test func success() {
        snapshot(ShareSuccessView(peopleCount: 4, totalCents: 13_282, onNewBill: {}, onBack: {}), "success")
    }

    // MARK: Small phone and landscape

    private func screens() -> [(String, AnyView)] {
        [
            ("home", AnyView(NavigationStack { HomeView(animatesMascot: false) }.environment(AppRouter()).environment(BillStore.live(arguments: ["--uitesting"])).environment(ScanFlow.preview()))),
            ("review", AnyView(NavigationStack { ReviewView() }.environment(store(ReviewSamples.parsedSession())).environment(AppRouter()))),
            ("people", AnyView(NavigationStack { PeopleView() }.environment(store(SampleBill.midway())).environment(AppRouter()))),
            ("mark", AnyView(NavigationStack { AssignScreen(model: assignModel(SampleBill.midway())) }.environment(AppRouter()))),
            ("totals", AnyView(NavigationStack { TotalsView() }.environment(store(TotalsSamples.mismatch())).environment(AppRouter()))),
        ]
    }

    @Test func smallPhoneAtXXXLarge() {
        for (name, view) in screens() {
            assertDesignSnapshot(view, named: "small-\(name)", variants: [.xxxLargeLightSpanish, .xxxLargeDarkEnglish], width: 375, fixedHeight: 667)
        }
    }

    @Test func landscape() {
        for (name, view) in screens() {
            assertDesignSnapshot(view, named: "landscape-\(name)", variants: [.lightSpanish, .xxxLargeDarkEnglish], width: 844, fixedHeight: 390, compactHeight: true)
        }
    }
}
