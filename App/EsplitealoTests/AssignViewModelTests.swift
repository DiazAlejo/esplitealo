import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// The Mark items screen's logic: who has what, the live per-person pre-tax subtotals, quantity lines marked unit by
/// unit, the unassigned block, "split the rest evenly", paint mode and the assign sheet. The model reads the bill
/// from the `BillStore` and changes it only through `store.update`, so every edit is autosaved.
///
/// `AssignSamples.table()` is the Fonda Doña Lola receipt with four people and nothing marked yet; `quantities()` has
/// a ×3 line and a ×2 line of $7.01 (an odd cent), for the unit-by-unit cases.
@MainActor
struct AssignViewModelTests {
    let drafts = RecordingDraftStore()

    // People (index = position at the table) and items of `AssignSamples.table()`.
    let marisol = AssignSamples.personID(1)
    let hector = AssignSamples.personID(2)
    let keishla = AssignSamples.personID(3)
    let yadiel = AssignSamples.personID(4)
    let surtido = AssignSamples.itemID(3) // $14.00
    let mofongo = AssignSamples.itemID(4) // $22.00
    let flan = AssignSamples.itemID(8) // $9.00

    // Items of `AssignSamples.quantities()`.
    let medalla = AssignSamples.quantityItemID(1) // 3 × $5.00
    let tostones = AssignSamples.quantityItemID(3) // 2 units, $7.01 in all

    func makeModel(_ session: BillSession = AssignSamples.table()) -> (model: AssignViewModel, store: BillStore) {
        let store = BillStore(draftStore: drafts, clock: ManualClock())
        store.startNewBill(draft: session.draft)
        store.update { $0 = session }
        return (AssignViewModel(store: store), store)
    }

    private func row(_ model: AssignViewModel, _ id: UUID) throws -> AssignViewModel.Row {
        try #require(model.rows.first { $0.id == id })
    }

    private func subtotals(_ model: AssignViewModel) -> [Int] {
        model.people.map(\.subtotalCents)
    }

    // MARK: The chips

    @Test func chipsFollowTheTableWithTheirPersonColourAndStartAtZero() {
        let (model, _) = makeModel()
        #expect(model.people.map(\.name) == ["Marisol", "Héctor", "Keishla", "Yadiel"])
        #expect(model.people.map(\.colorIndex) == [0, 1, 2, 3])
        #expect(subtotals(model) == [0, 0, 0, 0])
    }

    @Test func aChipSubtotalIsThePersonsPreTaxShareAndUpdatesAtOnce() {
        let (model, _) = makeModel()
        model.toggle(marisol, on: mofongo)
        #expect(subtotals(model) == [2200, 0, 0, 0])
        model.toggle(hector, on: mofongo)
        #expect(subtotals(model) == [1100, 1100, 0, 0])
        model.toggle(marisol, on: mofongo)
        #expect(subtotals(model) == [0, 2200, 0, 0])
    }

    @Test func chipSubtotalsAddUpToWhatIsMarkedWithoutLosingACent() {
        let (model, _) = makeModel()
        model.toggle(marisol, on: surtido)
        model.toggle(hector, on: surtido)
        model.toggle(keishla, on: surtido)
        model.toggle(yadiel, on: flan)
        #expect(subtotals(model).reduce(0, +) == 1400 + 900)
    }

    // MARK: Equal split by default

    @Test func onePersonGetsTheWholeItem() throws {
        let (model, _) = makeModel()
        model.toggle(keishla, on: flan)
        let flanRow = try row(model, flan)
        #expect(flanRow.assigneeIDs == [keishla])
        #expect(flanRow.units[0].sharesCents == [keishla: 900])
    }

    @Test func severalPeopleSplitAnItemEquallyAndTheExtraCentFollowsTheListOrder() throws {
        let (model, _) = makeModel()
        for person in [keishla, marisol, hector] { model.toggle(person, on: surtido) }
        let surtidoRow = try row(model, surtido)
        // The list order, not the order of the taps: Marisol and Héctor are ahead of Keishla.
        #expect(surtidoRow.assigneeIDs == [marisol, hector, keishla])
        #expect(surtidoRow.units[0].sharesCents == [marisol: 467, hector: 467, keishla: 466])
        #expect(subtotals(model) == [467, 467, 466, 0])
    }

    @Test func markingEveryoneThenSplitsAnEvenAmountInFourAndTakingOnePersonOffRecomputes() throws {
        let (model, _) = makeModel()
        model.toggleEveryone(on: flan)
        #expect(subtotals(model) == [225, 225, 225, 225])
        model.toggle(yadiel, on: flan)
        #expect(subtotals(model) == [300, 300, 300, 0])
    }

    @Test func markingEveryoneAgainClearsTheItem() throws {
        let (model, _) = makeModel()
        model.toggleEveryone(on: flan)
        model.toggleEveryone(on: flan)
        #expect(try row(model, flan).state == .unassigned)
        #expect(subtotals(model) == [0, 0, 0, 0])
    }

    @Test func clearingAnItemPutsItBackInTheUnassignedBlock() throws {
        let (model, _) = makeModel()
        model.toggle(hector, on: flan)
        model.clear(flan)
        #expect(try row(model, flan).state == .unassigned)
        #expect(model.unassignedUnitCount == 8)
    }

    // MARK: Unassigned items and progress

    @Test func everyItemStartsUnassignedAndFlagged() {
        let (model, _) = makeModel()
        #expect(model.rows.count == 8)
        #expect(model.rows.allSatisfy { $0.state == .unassigned })
        #expect(model.totalUnitCount == 8)
        #expect(model.assignedUnitCount == 0)
        #expect(model.unassignedUnitCount == 8)
        #expect(model.unassignedCents == 10_100)
        #expect(!model.isComplete)
    }

    @Test func progressAndTheUnassignedAmountFollowEveryMark() {
        let (model, _) = makeModel()
        model.toggle(marisol, on: mofongo)
        model.toggle(hector, on: flan)
        #expect(model.assignedUnitCount == 2)
        #expect(model.unassignedUnitCount == 6)
        #expect(model.unassignedCents == 10_100 - 2200 - 900)
    }

    @Test func markingEveryItemCompletesTheBill() {
        let (model, _) = makeModel()
        for row in model.rows { model.toggle(marisol, on: row.id) }
        #expect(model.isComplete)
        #expect(model.unassignedUnitCount == 0)
        #expect(model.unassignedCents == 0)
    }

    @Test func aMidwayBillShowsSixOfEightAndTwoUnassigned() {
        let (model, _) = makeModel(SampleBill.midway())
        #expect(model.assignedUnitCount == 6)
        #expect(model.unassignedUnitCount == 2)
        #expect(model.unassignedCents == 400 + 900)
    }

    // MARK: Quantity lines, unit by unit

    @Test func aQuantityLineHasOneUnitPerPieceAndTheUnitPricesAddUpToTheLine() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        let medallaRow = try row(model, medalla)
        #expect(medallaRow.quantity == 3)
        #expect(medallaRow.units.map(\.priceCents) == [500, 500, 500])
        // An odd line total: the leftover cent goes to the first unit, as the calculator does.
        let tostonesRow = try row(model, tostones)
        #expect(tostonesRow.units.map(\.priceCents) == [351, 350])
        #expect(tostonesRow.units.map(\.priceCents).reduce(0, +) == tostonesRow.totalCents)
    }

    @Test func eachUnitIsMarkedOnItsOwnAndTheLineIsPartlyAssigned() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.toggle(marisol, on: medalla, scope: .unit(0))
        let medallaRow = try row(model, medalla)
        #expect(medallaRow.state == .partlyAssigned)
        #expect(medallaRow.units.map(\.assigneeIDs) == [[marisol], [], []])
        #expect(medallaRow.unassignedUnitCount == 2)
        #expect(model.totalUnitCount == 7, "3 + 1 + 2 + 1")
        #expect(model.unassignedUnitCount == 6)
        #expect(model.assignedUnitCount == 1)
        #expect(subtotals(model).first == 500)
    }

    @Test func differentPeopleCanTakeDifferentUnitsOfOneLine() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.toggle(marisol, on: tostones, scope: .unit(0))
        model.toggle(hector, on: tostones, scope: .unit(1))
        #expect(try row(model, tostones).state == .assigned)
        #expect(subtotals(model)[0] == 351)
        #expect(subtotals(model)[1] == 350)
    }

    @Test func aUnitSharedByTwoSplitsThatUnitsPriceEqually() {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.toggle(marisol, on: tostones, scope: .unit(0))
        model.toggle(hector, on: tostones, scope: .unit(0))
        model.toggle(hector, on: tostones, scope: .unit(1))
        // Unit 0 costs 3.51: Marisol 1.76 (the odd cent), Héctor 1.75; unit 1 costs 3.50, all Héctor's.
        #expect(subtotals(model)[0] == 176)
        #expect(subtotals(model)[1] == 175 + 350)
    }

    @Test func theWholeLineToggleMarksEveryUnitAtOnce() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.toggle(keishla, on: medalla)
        let medallaRow = try row(model, medalla)
        #expect(medallaRow.state == .assigned)
        #expect(medallaRow.units.map(\.assigneeIDs) == [[keishla], [keishla], [keishla]])
        #expect(subtotals(model)[2] == 1500)
        // Toggling the same person again takes them off every unit.
        model.toggle(keishla, on: medalla)
        #expect(try row(model, medalla).state == .unassigned)
    }

    @Test func theWholeLineToggleAddsAPersonWhoHasOnlySomeUnits() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.toggle(marisol, on: medalla, scope: .unit(1))
        model.toggle(marisol, on: medalla) // she has one of three: this adds her to the rest
        #expect(try row(model, medalla).units.map(\.assigneeIDs) == [[marisol], [marisol], [marisol]])
    }

    @Test func splitRestEvenlyFillsEveryUnmarkedUnitOfAQuantityLine() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.toggle(marisol, on: medalla, scope: .unit(0))
        model.splitRestEvenly()
        let medallaRow = try row(model, medalla)
        #expect(medallaRow.units[0].assigneeIDs == [marisol], "a unit that already has someone is left alone")
        #expect(medallaRow.units[1].assigneeIDs.count == 3)
        #expect(model.isComplete)
    }

    // MARK: Split the rest evenly, and Review split

    @Test func splitTheRestEvenlyGivesEveryUnassignedItemToEveryoneAndKeepsWhatWasMarked() throws {
        let (model, _) = makeModel(SampleBill.midway())
        let before = model.people.map(\.subtotalCents)
        model.splitRestEvenly()
        #expect(model.isComplete)
        let jugo = try row(model, AssignSamples.itemID(1))
        #expect(jugo.assigneeIDs.count == 4)
        #expect(try row(model, AssignSamples.itemID(2)).assigneeIDs == [hector], "marked items keep their people")
        // The two unassigned items ($4.00 and $9.00) are split among four: $3.25 each.
        #expect(zip(before, model.people.map(\.subtotalCents)).map { $1 - $0 } == [325, 325, 325, 325])
    }

    @Test func reviewSplitWithItemsLeftDoesNotAdvanceAndShowsTheWarning() {
        let (model, _) = makeModel(SampleBill.midway())
        #expect(!model.showsWarning)
        #expect(model.reviewSplit() == .blocked(unassignedUnitCount: 2))
        #expect(model.showsWarning)
    }

    @Test func theWarningGoesAwayOnceTheLastItemIsMarked() {
        let (model, _) = makeModel(SampleBill.midway())
        _ = model.reviewSplit()
        model.toggle(marisol, on: AssignSamples.itemID(1))
        #expect(model.showsWarning, "one item is still left")
        model.toggle(marisol, on: flan)
        #expect(!model.showsWarning)
    }

    @Test func splittingTheRestClearsTheWarningAndReviewSplitMovesOn() {
        let (model, _) = makeModel(SampleBill.midway())
        _ = model.reviewSplit()
        model.splitRestEvenly()
        #expect(!model.showsWarning)
        #expect(model.reviewSplit() == .proceed)
    }

    @Test func reviewSplitWithEverythingMarkedProceeds() {
        let (model, _) = makeModel(SampleBill.complete())
        #expect(model.isComplete)
        #expect(model.reviewSplit() == .proceed)
        #expect(!model.showsWarning)
    }

    // MARK: Paint mode

    @Test func tappingAChipPaintsForThatPersonAndTappingItAgainStops() {
        let (model, _) = makeModel()
        model.togglePainting(hector)
        #expect(model.paintingID == hector)
        #expect(model.people.first { $0.id == hector }?.isPainting == true)
        model.togglePainting(keishla)
        #expect(model.paintingID == keishla, "another chip switches the painter")
        model.togglePainting(keishla)
        #expect(model.paintingID == nil)
    }

    @Test func whilePaintingATapOnAnItemMarksOrUnmarksThePainterInsteadOfOpeningTheSheet() throws {
        let (model, _) = makeModel()
        model.togglePainting(hector)
        model.tapRow(flan)
        #expect(model.sheet == nil)
        #expect(try row(model, flan).assigneeIDs == [hector])
        model.tapRow(surtido)
        #expect(subtotals(model)[1] == 900 + 1400)
        model.tapRow(flan)
        #expect(try row(model, flan).state == .unassigned)
    }

    @Test func paintingAQuantityLineMarksEveryUnit() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.togglePainting(marisol)
        model.tapRow(medalla)
        #expect(try row(model, medalla).state == .assigned)
        #expect(subtotals(model)[0] == 1500)
    }

    @Test func tryingToReviewTheSplitWithItemsLeftStopsPainting() {
        let (model, _) = makeModel()
        model.togglePainting(hector)
        _ = model.reviewSplit()
        #expect(model.paintingID == nil)
    }

    // MARK: The assign sheet

    @Test func tappingAnItemOpensItsSheetAndDoneClosesIt() {
        let (model, _) = makeModel()
        model.tapRow(mofongo)
        #expect(model.sheet?.itemID == mofongo)
        #expect(model.sheetContent?.itemName == "Mofongo de camarones")
        model.closeSheet()
        #expect(model.sheet == nil)
        #expect(model.sheetContent == nil)
    }

    @Test func theSheetListsEveryoneAtTheTableWithTheirColourAndMark() throws {
        let (model, _) = makeModel()
        model.toggle(hector, on: mofongo)
        model.tapRow(mofongo)
        let content = try #require(model.sheetContent)
        #expect(content.people.map(\.name) == ["Marisol", "Héctor", "Keishla", "Yadiel"])
        #expect(content.people.map(\.colorIndex) == [0, 1, 2, 3])
        #expect(content.people.map(\.mark) == [.none, .all, .none, .none])
        #expect(content.people[1].shareCents == 2200)
        #expect(content.people[0].shareCents == nil)
    }

    @Test func theSheetNoteSaysWhatIsMissingWhoHasItAndHowItIsSplit() throws {
        let (model, _) = makeModel()
        model.tapRow(surtido)
        #expect(model.sheetContent?.note == .pickOne)
        model.toggle(marisol, on: surtido)
        #expect(model.sheetContent?.note == .all)
        model.toggle(hector, on: surtido)
        #expect(model.sheetContent?.note == .split(ways: 2))
    }

    @Test func theSheetShowsTheLeftOverCentsAndWhoGetsThem() throws {
        let (model, _) = makeModel()
        model.tapRow(surtido)
        for person in [marisol, hector, keishla] { model.toggle(person, on: surtido) }
        // $14.00 ÷ 3 leaves 2¢: Marisol and Héctor pay it.
        #expect(model.sheetContent?.note == .leftover(ways: 3, cents: 2, names: ["Marisol", "Héctor"]))
        #expect(model.sheetContent?.people.map(\.shareCents) == [467, 467, 466, nil])
    }

    @Test func theSheetToggleEveryoneReadsClearOnceEveryoneIsIn() throws {
        let (model, _) = makeModel()
        model.tapRow(flan)
        #expect(model.sheetContent?.everyoneSelected == false)
        model.toggleEveryone(on: flan)
        #expect(model.sheetContent?.everyoneSelected == true)
    }

    @Test func theSheetOfAQuantityLineStartsOnTheWholeLineAndCanPickAUnit() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.tapRow(medalla)
        #expect(model.sheet?.scope == .all)
        #expect(model.sheetContent?.unitCount == 3)
        model.selectScope(.unit(1))
        #expect(model.sheet?.scope == .unit(1))
        #expect(model.sheetContent?.totalCents == 500, "a unit shows the price of that unit")
        model.toggle(hector, on: medalla, scope: .unit(1))
        #expect(model.sheetContent?.people[1].mark == .all)
        model.selectScope(.all)
        #expect(model.sheetContent?.people[1].mark == .some(1), "on the whole-line view, one of three units")
        #expect(model.sheetContent?.people[1].shareCents == 500)
    }

    @Test func aSingleItemSheetHasNoUnitPicker() {
        let (model, _) = makeModel()
        model.tapRow(flan)
        #expect(model.sheetContent?.unitCount == 1)
        #expect(model.sheet?.scope == .all)
    }

    @Test func theSheetClosesWhenItsItemIsGone() {
        let (model, store) = makeModel()
        model.tapRow(flan)
        store.update { $0.applyDraft(ReceiptDraftEditing.deleteItem(in: $0.draft, itemID: flan)) }
        #expect(model.sheetContent == nil)
    }

    // MARK: VoiceOver actions

    @Test func anUnassignedRowOffersEachPersonAndEveryone() {
        let (model, _) = makeModel()
        #expect(model.actions(for: flan) == [
            .mark(marisol), .mark(hector), .mark(keishla), .mark(yadiel), .markEveryone,
        ])
    }

    @Test func aMarkedRowOffersToTakeThatPersonOffAndToClear() {
        let (model, _) = makeModel()
        model.toggle(hector, on: flan)
        #expect(model.actions(for: flan) == [
            .mark(marisol), .unmark(hector), .mark(keishla), .mark(yadiel), .markEveryone, .clear,
        ])
    }

    @Test func onceEveryoneIsInTheRowOffersToTakeEachOffAndNoEveryone() {
        let (model, _) = makeModel()
        model.toggleEveryone(on: flan)
        #expect(model.actions(for: flan) == [
            .unmark(marisol), .unmark(hector), .unmark(keishla), .unmark(yadiel), .clear,
        ])
    }

    @Test func performingAnActionMarksTheWholeLine() throws {
        let (model, _) = makeModel(AssignSamples.quantities())
        model.perform(.mark(hector), on: medalla)
        #expect(try row(model, medalla).units.map(\.assigneeIDs) == [[hector], [hector], [hector]])
        model.perform(.markEveryone, on: tostones)
        #expect(try row(model, tostones).assigneeIDs.count == 3)
        model.perform(.unmark(hector), on: medalla)
        model.perform(.clear, on: tostones)
        #expect(try row(model, medalla).state == .unassigned)
        #expect(try row(model, tostones).state == .unassigned)
    }

    // MARK: Edits go through the store

    @Test func everyMarkIsSavedWithTheBill() {
        let (model, store) = makeModel()
        model.toggle(yadiel, on: flan)
        store.saveNow()
        #expect(drafts.stored?.assignments.map(\.participantIDs) == [[yadiel]])
    }

    @Test func nothingHappensWithoutABill() {
        let store = BillStore(draftStore: drafts, clock: ManualClock())
        let model = AssignViewModel(store: store)
        model.toggle(marisol, on: flan)
        model.splitRestEvenly()
        #expect(model.rows.isEmpty)
        #expect(model.people.isEmpty)
        #expect(model.reviewSplit() == .proceed)
    }
}
