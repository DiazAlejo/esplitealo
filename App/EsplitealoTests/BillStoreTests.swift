import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

@MainActor
struct BillStoreTests {
    let clock = ManualClock()
    let drafts = RecordingDraftStore()

    func makeStore(drafts: RecordingDraftStore? = nil) -> BillStore {
        BillStore(draftStore: drafts ?? self.drafts, clock: clock, debounce: .milliseconds(500))
    }

    /// Lets the debounce task register on the fake clock, moves time, and waits for the save to finish.
    func advance(_ store: BillStore, by duration: Duration) async {
        await clock.waitForSleepers()
        clock.advance(by: duration)
        await store.pendingSave?.value
    }

    // MARK: Starting

    @Test func startsWithoutABill() {
        let store = makeStore()
        #expect(store.session == nil)
        #expect(store.resumeCandidate == nil)
    }

    @Test func startingANewBillCreatesAnEmptySession() {
        let store = makeStore()
        store.startNewBill()
        #expect(store.session?.draft.items.isEmpty == true)
        #expect(store.session?.participants.isEmpty == true)
    }

    @Test func aBlankBillIsNeverWorthSaving() async {
        let store = makeStore()
        store.startNewBill()
        #expect(store.pendingSave == nil)
        #expect(drafts.saveCount == 0)
    }

    // MARK: Autosave

    @Test func editsAreSavedOnlyAfterTheDebounceInterval() async {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        await clock.waitForSleepers()

        clock.advance(by: .milliseconds(499))
        await Task.yield()
        #expect(drafts.saveCount == 0)

        await advance(store, by: .milliseconds(1))
        #expect(drafts.saveCount == 1)
        #expect(drafts.stored == store.session)
    }

    @Test func aBurstOfEditsWritesOnce() async {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        for name in ["Marisol", "Héctor", "Keishla"] {
            store.update { $0.addParticipant(name: name) }
            clock.advance(by: .milliseconds(100))
        }
        await advance(store, by: .milliseconds(500))
        #expect(drafts.saveCount == 1)
        #expect(drafts.stored?.participants.map(\.name) == ["Marisol", "Héctor", "Keishla"])
    }

    @Test func eachQuietPeriodWritesAgain() async {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        await advance(store, by: .milliseconds(500))
        store.update { $0.addParticipant(name: "Héctor") }
        await advance(store, by: .milliseconds(500))
        #expect(drafts.saveCount == 2)
        #expect(drafts.stored?.participants.count == 2)
    }

    @Test func saveNowWritesImmediatelyAndCancelsThePendingSave() async {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        store.saveNow()
        #expect(drafts.saveCount == 1)
        await clock.waitForSleepers(count: 0)
        clock.advance(by: .seconds(5))
        await Task.yield()
        #expect(drafts.saveCount == 1)
    }

    @Test func aFailedSaveIsReportedAndTheNextEditTriesAgain() async {
        let store = makeStore()
        drafts.failSaves(true)
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        await advance(store, by: .milliseconds(500))
        #expect(store.saveError != nil)
        #expect(drafts.saveCount == 0)

        drafts.failSaves(false)
        store.update { $0.addParticipant(name: "Héctor") }
        await advance(store, by: .milliseconds(500))
        #expect(store.saveError == nil)
        #expect(drafts.stored?.participants.count == 2)
    }

    @Test func removingEverythingDeletesTheDraft() async {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        await advance(store, by: .milliseconds(500))
        #expect(drafts.saveCount == 1)

        store.update { $0.applyDraft(ReceiptDraft(items: [])) }
        await advance(store, by: .milliseconds(500))
        #expect(drafts.stored == nil)
    }

    // MARK: Finishing

    @Test func finishingTheBillDeletesTheDraftAndClearsTheSession() async {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        await advance(store, by: .milliseconds(500))
        #expect(drafts.stored != nil)

        store.finishBill()
        #expect(store.session == nil)
        #expect(drafts.stored == nil)
    }

    @Test func finishingCancelsASaveThatIsStillWaiting() async {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        store.finishBill()
        await clock.waitForSleepers(count: 0)
        clock.advance(by: .seconds(5))
        await Task.yield()
        #expect(drafts.saveCount == 0)
        #expect(drafts.stored == nil)
    }

    // MARK: Resuming

    @Test func aSavedDraftIsOfferedOnLaunchAndNotOpenedWithoutAsking() {
        let saved = SampleBill.midway()
        let store = makeStore(drafts: RecordingDraftStore(draft: saved))
        store.loadSavedDraft()
        #expect(store.resumeCandidate == saved)
        #expect(store.session == nil)
    }

    @Test func resumingOpensTheSavedBill() {
        let saved = SampleBill.midway()
        let store = makeStore(drafts: RecordingDraftStore(draft: saved))
        store.loadSavedDraft()
        store.resumeSavedDraft()
        #expect(store.session == saved)
        #expect(store.resumeCandidate == nil)
    }

    @Test func startingOverDeletesTheSavedBill() {
        let recording = RecordingDraftStore(draft: SampleBill.midway())
        let store = makeStore(drafts: recording)
        store.loadSavedDraft()
        store.discardSavedDraft()
        #expect(store.resumeCandidate == nil)
        #expect(store.session == nil)
        #expect(recording.stored == nil)
    }

    @Test func noDraftMeansNoPrompt() {
        let store = makeStore()
        store.loadSavedDraft()
        #expect(store.resumeCandidate == nil)
    }

    @Test func aDraftThatCannotBeReadIsDeletedAndNotOffered() {
        let recording = RecordingDraftStore(corrupt: true)
        let store = makeStore(drafts: recording)
        store.loadSavedDraft()
        #expect(store.resumeCandidate == nil)
        #expect(recording.deleteCount == 1)
    }

    @Test func resumingDoesNotRewriteTheDraftUntilSomethingChanges() async {
        let recording = RecordingDraftStore(draft: SampleBill.midway())
        let store = makeStore(drafts: recording)
        store.loadSavedDraft()
        store.resumeSavedDraft()
        #expect(store.pendingSave == nil)
        #expect(recording.saveCount == 0)
    }

    // MARK: A bill in progress

    @Test func noBillMeansNothingInProgress() {
        let store = makeStore()
        #expect(store.billInProgress == nil)
        #expect(store.hasBillInProgress == false)
    }

    @Test func aBlankBillIsNotInProgress() {
        let store = makeStore()
        store.startNewBill()
        #expect(store.billInProgress == nil)
        #expect(store.hasBillInProgress == false)
    }

    @Test func aBillWithItemsIsInProgressWithItsItemCountPrintedTotalAndWayBack() {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.scannedDraft())
        let session = SampleBill.scanned()
        let progress = store.billInProgress
        #expect(store.hasBillInProgress)
        #expect(progress?.itemCount == session.draft.items.count)
        #expect(progress?.totalCents == session.printedReceiptTotalCents)
        #expect(progress?.resumePath == [.review])
    }

    @Test func withoutAPrintedTotalTheItemsSumIsTheTotal() {
        let store = makeStore()
        var draft = SampleBill.scannedDraft()
        draft.total = nil
        store.startNewBill(draft: draft)
        #expect(store.billInProgress?.totalCents == store.session?.netItemsSubtotalCents)
    }

    @Test func aBillWithOnlyPeopleIsInProgress() {
        let store = makeStore()
        store.startNewBill()
        store.update { $0.addParticipant(name: "Marisol") }
        #expect(store.hasBillInProgress)
        #expect(store.billInProgress?.itemCount == 0)
    }

    @Test func theWayBackFollowsTheStepTheBillReached() {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.midway() }
        #expect(store.billInProgress?.resumePath == [.review, .people, .mark])
        store.update { $0 = SampleBill.complete() }
        #expect(store.billInProgress?.resumePath == [.review, .people, .mark, .totals])
    }

    @Test func abandoningTheBillForgetsItAndDeletesTheDraftFile() async {
        let recording = RecordingDraftStore()
        let store = makeStore(drafts: recording)
        store.startNewBill(draft: SampleBill.scannedDraft())
        await advance(store, by: .milliseconds(500))
        #expect(recording.stored != nil)
        store.finishBill()
        #expect(store.session == nil)
        #expect(store.hasBillInProgress == false)
        #expect(recording.stored == nil)
    }

    @Test func replacingABillWithABlankOneAlsoRemovesTheOldDraftFile() async {
        let recording = RecordingDraftStore()
        let store = makeStore(drafts: recording)
        store.startNewBill(draft: SampleBill.scannedDraft())
        await advance(store, by: .milliseconds(500))
        #expect(recording.stored != nil)
        store.startNewBill()
        #expect(recording.stored == nil, "a stale draft must not be offered at the next launch")
    }

    // MARK: A bill that was shared

    @Test func sharingDeletesTheDraftFileButKeepsTheBillInMemory() async {
        let recording = RecordingDraftStore()
        let store = makeStore(drafts: recording)
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        await advance(store, by: .milliseconds(500))
        #expect(recording.stored != nil)

        store.billShared()
        #expect(recording.stored == nil)
        #expect(store.session == SampleBill.complete())
    }

    @Test func aSharedBillIsNoLongerInProgress() {
        let store = makeStore()
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        #expect(store.hasBillInProgress)
        store.billShared()
        #expect(store.hasBillInProgress == false)
        #expect(store.billInProgress == nil)
    }

    @Test func sharingCancelsASaveThatWasStillWaiting() async {
        let recording = RecordingDraftStore()
        let store = makeStore(drafts: recording)
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        store.billShared()
        #expect(store.pendingSave == nil)
        clock.advance(by: .seconds(5))
        await Task.yield()
        #expect(recording.stored == nil)
        #expect(recording.saveCount == 0)
    }

    @Test func goingToTheBackgroundAfterSharingDoesNotBringTheDraftBack() {
        let recording = RecordingDraftStore()
        let store = makeStore(drafts: recording)
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        store.billShared()
        store.saveNow()
        #expect(recording.stored == nil)
    }

    @Test func editingASharedBillMakesItLiveAndSavesItAgain() async {
        let recording = RecordingDraftStore()
        let store = makeStore(drafts: recording)
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        store.billShared()

        store.update { $0.addParticipant(name: "Nuevo") }
        #expect(store.hasBillInProgress)
        await advance(store, by: .milliseconds(500))
        #expect(recording.stored == store.session)
    }

    @Test func relaunchingAfterSharingDoesNotOfferTheFinishedBill() async {
        let recording = RecordingDraftStore()
        let first = makeStore(drafts: recording)
        first.startNewBill(draft: SampleBill.complete().draft)
        first.update { $0 = SampleBill.complete() }
        await advance(first, by: .milliseconds(500))
        first.billShared()

        let relaunched = makeStore(drafts: recording)
        relaunched.loadSavedDraft()
        #expect(relaunched.resumeCandidate == nil)
    }

    @Test func startingANewBillAfterSharingSavesNormally() async {
        let recording = RecordingDraftStore()
        let store = makeStore(drafts: recording)
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        store.billShared()

        store.startNewBill(draft: SampleBill.scannedDraft())
        #expect(store.hasBillInProgress)
        await advance(store, by: .milliseconds(500))
        #expect(recording.stored == store.session)
    }

    // MARK: Draft location

    @Test func theLiveStoreKeepsTheDraftInApplicationSupportAndOutOfBackups() throws {
        let directory = try DraftLocation.defaultDirectory(
            base: FileManager.default.temporaryDirectory.appendingPathComponent("esplitealo-\(UUID().uuidString)", isDirectory: true)
        )
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        #expect(directory.lastPathComponent == "Draft")
        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }
}
