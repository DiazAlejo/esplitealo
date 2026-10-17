import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// The store with the real draft file on disk, quitting and relaunching it the way iOS does: a new `BillStore` over the
/// same folder is a new launch. These are the journeys `BillStoreTests` cannot see because its store is in memory.
@MainActor
final class BillStoreOnDiskTests {
    let clock = ManualClock()
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("esplitealo-store-journey-\(UUID().uuidString)", isDirectory: true)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private var draftFile: URL { directory.appendingPathComponent(FileBillDraftStore.fileName) }

    private static let v1Fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // EsplitealoTests
        .deletingLastPathComponent() // App
        .deletingLastPathComponent() // repository
        .appendingPathComponent("Tests/Fixtures/BillSessions/v1-in-progress.json")

    /// A launch: a fresh store over the same folder, and its prompt answered the way the app does.
    func launch() -> BillStore {
        BillStore(draftStore: FileBillDraftStore(directory: directory), clock: clock, debounce: .milliseconds(500))
    }

    /// Lets the debounce task register on the fake clock, moves time past it, and waits for the write.
    func settle(_ store: BillStore) async {
        await clock.waitForSleepers()
        clock.advance(by: .milliseconds(500))
        await store.pendingSave?.value
    }

    /// The bill as the person left it, written the way the app writes it, then "killed" (the store is dropped).
    func leave(_ session: BillSession) async {
        let store = launch()
        store.startNewBill(draft: session.draft)
        store.update { $0 = session }
        await settle(store)
    }

    // MARK: Relaunching at every stage

    enum Stage: String, CaseIterable, Sendable {
        case scanned, peopleAdded, halfMarked, allMarked, allMarkedMismatch, quantityLines

        var session: BillSession {
            switch self {
            case .scanned: SampleBill.scanned()
            case .peopleAdded: AssignSamples.table()
            case .halfMarked: SampleBill.midway()
            case .allMarked: SampleBill.complete()
            case .allMarkedMismatch: TotalsSamples.mismatch()
            case .quantityLines: AssignSamples.quantities()
            }
        }

        /// Where the app puts the person back: Review with nobody at the table, Mark items with items left, else Totals.
        var path: [AppRoute] {
            switch self {
            case .scanned: [.review]
            case .peopleAdded, .halfMarked, .quantityLines: [.review, .people, .mark]
            case .allMarked, .allMarkedMismatch: [.review, .people, .mark, .totals]
            }
        }
    }

    @Test(arguments: Stage.allCases)
    func aRelaunchOffersTheIdenticalBillAndPutsItBackAtItsStep(stage: Stage) async throws {
        let saved = stage.session
        let path = stage.path
        await leave(saved)

        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.session == nil, "nothing opens before the person answers")
        #expect(relaunched.resumeCandidate == saved)

        relaunched.resumeSavedDraft()
        #expect(relaunched.session == saved)
        #expect(relaunched.billInProgress?.resumePath == path)
        #expect(relaunched.pendingSave == nil, "resuming alone does not rewrite the file")
    }

    @Test func aBillRelaunchedTwiceInARowIsStillTheSameBill() async {
        let saved = SampleBill.midway()
        await leave(saved)

        let second = launch()
        second.loadSavedDraft()
        second.resumeSavedDraft()
        second.saveNow()

        let third = launch()
        third.loadSavedDraft()
        #expect(third.resumeCandidate == saved)
    }

    @Test func discardingTheOfferedBillForgetsItForTheNextLaunchToo() async {
        await leave(SampleBill.midway())
        let second = launch()
        second.loadSavedDraft()
        second.discardSavedDraft()
        #expect(!FileManager.default.fileExists(atPath: draftFile.path))

        let third = launch()
        third.loadSavedDraft()
        #expect(third.resumeCandidate == nil)
    }

    // MARK: Autosave on disk

    @Test func theLastQuietEditIsOnDiskButOneStillInsideTheQuietPeriodIsNot() async throws {
        let store = launch()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        await settle(store)

        // A second edit, then the app is killed 400 ms later with no chance to go to the background first.
        store.update { $0.addParticipant(name: "Héctor") }
        await clock.waitForSleepers()
        clock.advance(by: .milliseconds(400))

        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate?.participants.map(\.name) == ["Marisol"], "at most the last half second is lost")
    }

    @Test func goingToTheBackgroundWritesTheEditThatWasStillWaiting() async {
        let store = launch()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        store.update { $0.addParticipant(name: "Héctor") }
        store.saveNow()

        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate?.participants.map(\.name) == ["Marisol", "Héctor"])
    }

    @Test func aBurstOfEditsIsOneWriteOfTheFinalBill() async throws {
        let store = launch()
        store.startNewBill(draft: SampleBill.scannedDraft())
        for name in ["Marisol", "Héctor", "Keishla", "Yadiel"] {
            store.update { $0.addParticipant(name: name) }
            clock.advance(by: .milliseconds(100))
        }
        await settle(store)

        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == [FileBillDraftStore.fileName])
        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate?.participants.count == 4)
    }

    // MARK: Damaged files: start clean, keep going

    enum Damage: String, CaseIterable, Sendable {
        case empty, cutInHalf, notJSON, wrongShape, fromANewerApp

        var contents: String {
            switch self {
            case .empty: ""
            case .cutInHalf: #"{"schemaVersion":2,"draft":{"items":[{"id":"10000000-0000-0000-0000-0000000"#
            case .notJSON: "this is not a bill"
            case .wrongShape: #"{"schemaVersion":2,"draft":42}"#
            case .fromANewerApp: #"{"schemaVersion":99}"#
            }
        }
    }

    @Test(arguments: Damage.allCases)
    func aDamagedDraftStartsCleanWithoutAPromptAndTheNextBillIsSavedNormally(damage: Damage) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(damage.contents.utf8).write(to: draftFile)

        let store = launch()
        store.loadSavedDraft()
        #expect(store.resumeCandidate == nil, "a file that cannot be read is not offered")
        #expect(!FileManager.default.fileExists(atPath: draftFile.path), "and it is removed so it cannot trouble the next launch")

        // The person scans a new receipt and goes on as if nothing had happened.
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Ana") }
        await settle(store)
        #expect(store.saveError == nil)

        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate?.participants.map(\.name) == ["Ana"])
    }

    @Test func aCutShortWriteLeavesTheLastCompleteBillOffered() async throws {
        let saved = SampleBill.midway()
        await leave(saved)
        // The temporary file an interrupted atomic write leaves next to the real draft.
        try Data(#"{"schemaVersion":2,"dra"#.utf8).write(to: directory.appendingPathComponent("draft.json.sb-deadbeef-ABC123"))

        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate == saved)
    }

    @Test func aFolderThatCannotBeWrittenKeepsTheBillInMemoryAndDoesNotLoseTheLastSave() async throws {
        let saved = SampleBill.scanned()
        await leave(saved)
        let store = launch()
        store.loadSavedDraft()
        store.resumeSavedDraft()

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }
        try #require(!FileManager.default.isWritableFile(atPath: directory.path), "this account can write to a read-only folder")

        store.update { $0.addParticipant(name: "Ana") }
        await settle(store)
        #expect(store.saveError != nil)
        #expect(store.session?.participants.map(\.name) == ["Ana"], "the screen keeps working")

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate == saved, "the previous save is still whole")

        // Once the folder works again the next edit is saved.
        store.update { $0.addParticipant(name: "Luis") }
        await settle(store)
        #expect(store.saveError == nil)
    }

    // MARK: Older drafts

    @Test func aVersion1DraftIsOfferedResumedAndSavedBackAsTheCurrentVersion() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Self.v1Fixture, to: draftFile)

        let store = launch()
        store.loadSavedDraft()
        let candidate = try #require(store.resumeCandidate)
        store.resumeSavedDraft()
        #expect(store.session == candidate)

        store.update { $0.addParticipant(name: "Nueva") }
        await settle(store)
        let written = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: draftFile)) as? [String: Any])
        #expect(written["schemaVersion"] as? Int == BillSession.currentSchemaVersion)

        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate == store.session)
    }

    // MARK: Finished bills

    @Test func sharingRemovesTheFileAndAnEditAfterwardsBringsItBack() async {
        let store = launch()
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        await settle(store)
        #expect(FileManager.default.fileExists(atPath: draftFile.path))

        store.billShared()
        #expect(!FileManager.default.fileExists(atPath: draftFile.path))
        let afterShare = launch()
        afterShare.loadSavedDraft()
        #expect(afterShare.resumeCandidate == nil)

        // "Back" from the success screen and an edit makes the bill live again.
        store.update { $0.tip = .custom(cents: 1000) }
        await settle(store)
        let afterEdit = launch()
        afterEdit.loadSavedDraft()
        #expect(afterEdit.resumeCandidate?.tip == .custom(cents: 1000))
    }

    @Test func finishingOrAbandoningRemovesTheFile() async {
        let store = launch()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        await settle(store)
        #expect(FileManager.default.fileExists(atPath: draftFile.path))

        store.finishBill()
        #expect(!FileManager.default.fileExists(atPath: draftFile.path))
        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate == nil)
    }

    // MARK: A big table

    @Test func aFortyItemBillWithEightPeopleSavesRestoresAndCostsLittleToEdit() async throws {
        let big = LargeBill.make()
        let store = launch()
        store.startNewBill(draft: big.draft)
        store.update { $0 = big }
        await settle(store)

        let relaunched = launch()
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate == big)

        // One edit on the big bill: the autosave is a single quick write of a small file.
        let duration = await ContinuousClock().measure {
            store.update { $0.tip = .percentage(percent: 25, basis: .preTaxSubtotal) }
            await settle(store)
        }
        #expect(duration < .seconds(2), "one autosave of the big bill took \(duration)")
        let size = try #require(try FileManager.default.attributesOfItem(atPath: draftFile.path)[.size] as? Int)
        #expect(size < 200_000)
    }
}

/// 40 lines and 8 people, all marked (the same shape as `LargeBillSanityTests` in the package tests).
enum LargeBill {
    static func make() -> BillSession {
        let people = ["Marisol", "Héctor", "Keishla", "Yadiel", "Ana", "Luis", "Carmen", "Joel"].enumerated().map {
            Participant(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0.offset + 1))!, name: $0.element, orderIndex: $0.offset)
        }
        let items = (1 ... 40).map { number in
            let quantity = number % 4 == 0 ? 2 + number % 3 : 1
            return DraftItem(
                id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", number))!,
                name: "Plato \(number)",
                quantity: quantity,
                lineTotal: DraftAmount(minorUnits: (350 + number * 137) * quantity)
            )
        }
        let subtotal = items.reduce(0) { $0 + $1.lineTotal.minorUnits }
        let tax = Int((Double(subtotal) * 0.115).rounded())
        var session = BillSession(
            draft: ReceiptDraft(
                items: items,
                subtotal: DraftAmount(minorUnits: subtotal),
                tax: DraftAmount(minorUnits: tax),
                total: DraftAmount(minorUnits: subtotal + tax)
            ),
            merchantName: "Fonda Doña Lola",
            date: Date(timeIntervalSince1970: 1_791_892_800),
            participants: people
        )
        for (index, item) in items.enumerated() {
            for unit in 0 ..< item.quantity {
                session.assignUnit(itemID: item.id, unitIndex: unit, participantIDs: [people[(index + unit) % people.count].id])
            }
        }
        return session
    }
}
