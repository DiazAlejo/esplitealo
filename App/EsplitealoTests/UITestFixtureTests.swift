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

    @Test func unsureIsAScanWithTwoPricesTheParserCouldNotRead() throws {
        let (store, _) = apply(["--uitesting", "--fixture=unsure"])
        let session = try #require(store.session)
        #expect(session.draft.items.count == 7)
        #expect(session.draft.activeWarnings.count == 2)
        #expect(session.draft.reconciles == false)
        #expect(session.participants.isEmpty)
    }

    @Test func scannedIsTheFixedReceiptWithNobodyAtTheTable() throws {
        let (store, _) = apply(["--uitesting", "--fixture=scanned"])
        #expect(store.session == SampleBill.scanned())
    }

    @Test func midwayHasFourPeopleAndItemsMarked() throws {
        let (store, _) = apply(["--uitesting", "--fixture=midway"])
        let expected = SampleBill.midway()
        #expect(store.session?.draft == expected.draft)
        #expect(store.session?.participants == expected.participants)
        // `SampleBill` builds the assignments from a dictionary, so their order differs between calls.
        #expect(Set(store.session?.assignments.map(\.itemID) ?? []) == Set(expected.assignments.map(\.itemID)))
        #expect(store.session?.assignments.count == expected.assignments.count)
    }

    @Test func tableIsTheFixedReceiptWithFourPeopleAndNothingMarked() throws {
        let (store, _) = apply(["--uitesting", "--fixture=table"])
        let session = try #require(store.session)
        #expect(session.draft == SampleBill.scanned().draft)
        #expect(session.participants.map(\.name) == SampleBill.people)
        #expect(session.assignments.isEmpty)
    }

    @Test func quantitiesHasLinesWithSeveralUnitsAndNothingMarked() throws {
        let (store, _) = apply(["--uitesting", "--fixture=quantities"])
        let session = try #require(store.session)
        #expect(session.draft.items.map(\.quantity) == [3, 1, 2, 1])
        #expect(session.participants.count == 3)
        #expect(session.assignments.isEmpty)
        #expect(session.draft.reconciles)
    }

    @Test func emptyIsABlankBill() throws {
        let (store, _) = apply(["--uitesting", "--fixture=empty"])
        #expect(store.session?.draft.items.isEmpty == true)
    }

    @Test func anUnknownFixtureStartsNoBill() {
        let (store, _) = apply(["--uitesting", "--fixture=nope"])
        #expect(store.session == nil)
    }

    @Test func startAtOpensTheScreenWithTheEarlierOnesBehindIt() {
        let cases: [(String, [AppRoute])] = [
            ("review", [.capture, .review]),
            ("people", [.capture, .review, .people]),
            ("totals", [.capture, .review, .people, .mark, .totals]),
        ]
        for (screen, path) in cases {
            let (_, router) = apply(["--uitesting", "--fixture=scanned", "--start-at=\(screen)"])
            #expect(router.path == path, "\(screen)")
        }
    }

    @Test func startAtWithAnUnknownScreenStaysOnHome() {
        let (_, router) = apply(["--uitesting", "--fixture=scanned", "--start-at=nowhere"])
        #expect(router.path.isEmpty)
    }
}
