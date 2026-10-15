import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// The Add people screen's logic: names, the table, and removing someone who already has items marked.
@MainActor
struct PeopleViewModelTests {
    let drafts = RecordingDraftStore()

    func makeModel(_ session: BillSession? = SampleBill.scanned()) -> (model: PeopleViewModel, store: BillStore) {
        let store = BillStore(draftStore: drafts, clock: ManualClock())
        if let session {
            store.startNewBill(draft: session.draft)
            store.update { $0 = session }
        }
        return (PeopleViewModel(store: store), store)
    }

    private func names(_ store: BillStore) -> [String] {
        store.session?.participants.map(\.name) ?? []
    }

    // MARK: Adding

    @Test func addingAPersonTrimsTheNameClearsTheFieldAndKeepsTheOrder() {
        let (model, store) = makeModel()
        model.nameDraft = "  Marisol "
        model.addPerson()
        model.nameDraft = "Héctor"
        model.addPerson()
        #expect(names(store) == ["Marisol", "Héctor"])
        #expect(model.nameDraft.isEmpty)
        #expect(model.message == nil)
        #expect(model.rows.map(\.name) == ["Marisol", "Héctor"])
    }

    @Test func personColoursFollowThePositionAtTheTable() {
        let (model, _) = makeModel(SampleBill.midway())
        #expect(model.rows.map(\.colorIndex) == [0, 1, 2, 3])
    }

    @Test func aBlankNameIsRefusedWithAMessage() {
        let (model, store) = makeModel()
        model.nameDraft = "   "
        model.addPerson()
        #expect(model.message == .nameMissing)
        #expect(names(store).isEmpty)
    }

    @Test func aNameAlreadyAtTheTableIsRefusedWhateverTheCaseOrAccents() {
        let (model, store) = makeModel(SampleBill.midway())
        model.nameDraft = "hector"
        model.addPerson()
        #expect(model.message == .duplicate("hector"))
        #expect(model.nameDraft == "hector", "the typed name stays so it can be fixed")
        #expect(names(store).count == 4)
        model.nameDraft = "Hector R"
        model.addPerson()
        #expect(model.message == nil)
        #expect(names(store).count == 5)
    }

    @Test func typingClearsAnOldMessage() {
        let (model, _) = makeModel()
        model.addPerson()
        #expect(model.message == .nameMissing)
        model.nameDraft = "A"
        #expect(model.message == nil)
    }

    @Test func nameLengthIsLimited() {
        let (model, _) = makeModel()
        model.nameDraft = String(repeating: "x", count: 40)
        #expect(model.nameDraft.count == PeopleViewModel.maxNameLength)
        #expect(PeopleViewModel.maxNameLength == 18)
    }

    @Test func continuingNeedsAtLeastOnePerson() {
        let (model, _) = makeModel()
        #expect(!model.canContinue)
        model.nameDraft = "Ana"
        model.addPerson()
        #expect(model.canContinue)
    }

    // MARK: Renaming

    @Test func renamingChangesOnlyTheName() {
        let (model, store) = makeModel(SampleBill.midway())
        let before = store.session!
        let id = before.participants[1].id
        model.beginRename(id: id)
        #expect(model.renaming?.id == id)
        #expect(model.renameDraft == "Héctor")
        model.renameDraft = "  Héctor R. "
        #expect(model.commitRename())
        #expect(names(store) == ["Marisol", "Héctor R.", "Keishla", "Yadiel"])
        #expect(store.session?.participants[1].id == id)
        #expect(store.session?.assignments == before.assignments)
        #expect(model.renaming == nil)
    }

    @Test func aPersonCanChangeTheCaseOfTheirOwnName() {
        let (model, store) = makeModel(SampleBill.midway())
        model.beginRename(id: store.session!.participants[0].id)
        model.renameDraft = "MARISOL"
        #expect(model.commitRename())
        #expect(names(store).first == "MARISOL")
    }

    @Test func renamingToSomeoneElsesNameOrNothingIsRefused() {
        let (model, store) = makeModel(SampleBill.midway())
        model.beginRename(id: store.session!.participants[0].id)
        model.renameDraft = "yadiel"
        #expect(!model.commitRename())
        #expect(model.renameMessage == .duplicate("yadiel"))
        model.renameDraft = " "
        #expect(!model.commitRename())
        #expect(model.renameMessage == .nameMissing)
        #expect(names(store).first == "Marisol")
        #expect(model.renaming != nil, "the sheet stays open to fix it")
        model.cancelRename()
        #expect(model.renaming == nil)
        #expect(model.renameMessage == nil)
    }

    // MARK: Removing

    @Test func removingSomeoneWithNothingMarkedHappensAtOnce() {
        let (model, store) = makeModel(SampleBill.midway())
        let yadielSolo = store.session!.participants[3].id
        store.update { $0.clearUnitAssignment(itemID: $0.draft.items[6].id, unitIndex: 0) }
        model.requestRemoval(id: yadielSolo)
        #expect(model.pendingRemoval == nil)
        #expect(names(store) == ["Marisol", "Héctor", "Keishla"])
    }

    @Test func removingSomeoneWithItemsMarkedAsksFirstAndSaysWhatWillHappen() throws {
        let (model, store) = makeModel(SampleBill.midway())
        let hector = store.session!.participants[1]
        model.requestRemoval(id: hector.id)

        let removal = try #require(model.pendingRemoval)
        #expect(removal.id == hector.id)
        #expect(removal.name == "Héctor")
        #expect(removal.assignedItemCount == 3)
        #expect(removal.orphanedItemNames == ["Medalla", "Pernil con gandules"])
        #expect(removal.sharedItemsRemain)
        #expect(names(store).count == 4, "nothing is removed until the user confirms")
    }

    @Test func keepingThePersonLeavesEverythingAsItWas() {
        let (model, store) = makeModel(SampleBill.midway())
        let before = store.session
        model.requestRemoval(id: before!.participants[1].id)
        model.cancelRemoval()
        #expect(model.pendingRemoval == nil)
        #expect(store.session == before)
    }

    @Test func confirmingRemovesThemAndOnlyTheirItemsGoBackToUnassigned() {
        let (model, store) = makeModel(SampleBill.midway())
        let session = store.session!
        let hector = session.participants[1]
        model.requestRemoval(id: hector.id)
        model.confirmRemoval()

        #expect(model.pendingRemoval == nil)
        #expect(names(store) == ["Marisol", "Keishla", "Yadiel"])
        let after = store.session!
        let medalla = session.draft.items[1].id
        let surtido = session.draft.items[2].id
        #expect(after.unassignedUnits.contains { $0.itemID == medalla })
        #expect(after.unassignedUnits.count == session.unassignedUnits.count + 2)
        let sharedAssignees = after.assignments.first { $0.itemID == surtido }?.participantIDs ?? []
        #expect(Set(sharedAssignees) == Set([session.participants[0].id, session.participants[2].id]))
    }

    @Test func nobodyCanRemoveTheLastPerson() {
        let (model, store) = makeModel(BillSession(draft: SampleBill.scannedDraft(), participants: [Participant(name: "Ana", orderIndex: 0)]))
        model.requestRemoval(id: store.session!.participants[0].id)
        #expect(names(store) == ["Ana"])
        #expect(model.message == .lastPerson)
        #expect(model.pendingRemoval == nil)
    }

    @Test func theLastPersonIsProtectedEvenWithItemsMarked() {
        var session = SampleBill.scanned()
        session.addParticipant(name: "Ana")
        session.splitRestEvenly()
        let (model, store) = makeModel(session)
        model.requestRemoval(id: session.participants[0].id)
        #expect(names(store) == ["Ana"])
        #expect(model.message == .lastPerson)
    }

    // MARK: The table

    @Test func eachRowCountsTheItemsMarkedForThatPerson() {
        let (model, _) = makeModel(SampleBill.midway())
        #expect(model.rows.map(\.assignedItemCount) == [2, 3, 2, 1])
    }

    @Test func anItemWithSeveralUnitsForOnePersonCountsOnce() {
        var draft = SampleBill.scannedDraft()
        draft.items[1] = DraftItem(id: draft.items[1].id, name: "Medalla", quantity: 2, lineTotal: DraftAmount(minorUnits: 1000), unitPrice: DraftAmount(minorUnits: 500))
        var session = BillSession(draft: draft)
        session.addParticipant(name: "Ana")
        session.addParticipant(name: "Bo")
        let ana = session.participants[0].id
        session.assignUnit(itemID: draft.items[1].id, unitIndex: 0, participantIDs: [ana])
        session.assignUnit(itemID: draft.items[1].id, unitIndex: 1, participantIDs: [ana])
        let (model, _) = makeModel(session)
        #expect(model.rows.map(\.assignedItemCount) == [1, 0])
    }

    // MARK: Store

    @Test func editsGoThroughTheStoreSoTheyAreAutosaved() {
        let (model, store) = makeModel()
        model.nameDraft = "Ana"
        model.addPerson()
        #expect(store.pendingSave != nil)
    }

    @Test func reachingTheScreenWithoutABillStartsAnEmptyOne() {
        let (model, store) = makeModel(nil)
        model.startBillIfNeeded()
        #expect(store.session != nil)
        model.nameDraft = "Ana"
        model.addPerson()
        #expect(names(store) == ["Ana"])
    }
}
