import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// The launch arguments UI tests use to start from a parsed receipt instead of the camera.
@MainActor
struct UITestFixtureTests {
    func apply(_ arguments: [String]) -> (store: BillStore, router: AppRouter) {
        let store = BillStore(draftStore: RecordingDraftStore(), clock: ManualClock())
        let router = AppRouter()
        UITestFixture.apply(arguments: arguments, store: store, router: router)
        return (store, router)
    }

    @Test func fixturesAreIgnoredOutsideUITesting() {
        let (store, router) = apply(["--fixture=parsed", "--start-at=review"])
        #expect(store.session == nil)
        #expect(router.path.isEmpty)
    }

    @Test func parsedIsAScanWithAFlaggedRowAndANonReconcilingReceipt() throws {
        let (store, _) = apply(["--uitesting", "--fixture=parsed"])
        let session = try #require(store.session)
        #expect(session.draft.items.count == 8)
        #expect(session.draft.reconciles == false)
        #expect(session.draft.items.filter { !$0.flags.isEmpty }.map(\.id) == [ReviewSamples.flanID])
        #expect(session.participants.isEmpty)
    }

    @Test func scannedIsTheFixedReceiptWithNobodyAtTheTable() throws {
        let (store, _) = apply(["--uitesting", "--fixture=scanned"])
        #expect(store.session == SampleBill.scanned())
    }

    @Test func midwayHasFourPeopleAndItemsMarked() throws {
        let (store, _) = apply(["--uitesting", "--fixture=midway"])
        #expect(store.session == SampleBill.midway())
    }

    @Test func emptyIsABlankBill() throws {
        let (store, _) = apply(["--uitesting", "--fixture=empty"])
        #expect(store.session?.draft.items.isEmpty == true)
    }

    @Test func anUnknownFixtureStartsNoBill() {
        let (store, _) = apply(["--uitesting", "--fixture=nope"])
        #expect(store.session == nil)
    }

    @Test(arguments: [("review", [AppRoute.capture, .review]), ("people", [.capture, .review, .people]), ("totals", [.capture, .review, .people, .mark, .totals])])
    func startAtOpensTheScreenWithTheEarlierOnesBehindIt(screen: String, path: [AppRoute]) {
        let (_, router) = apply(["--uitesting", "--fixture=scanned", "--start-at=\(screen)"])
        #expect(router.path == path)
    }

    @Test func startAtWithAnUnknownScreenStaysOnHome() {
        let (_, router) = apply(["--uitesting", "--fixture=scanned", "--start-at=nowhere"])
        #expect(router.path.isEmpty)
    }
}
