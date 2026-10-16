import EsplitealoCore
import SwiftUI
import Testing
@testable import Esplitealo

/// The Mark items screen in the states of the mockups (nothing marked, midway, the warning with items left, paint
/// mode, everything marked), a quantity line marked unit by unit, and the assign sheet.
@MainActor
struct AssignSnapshotTests {
    private func model(_ session: BillSession) -> AssignViewModel {
        let store = BillStore(draftStore: RecordingDraftStore(), clock: ManualClock())
        store.startNewBill(draft: session.draft)
        store.update { $0 = session }
        return AssignViewModel(store: store)
    }

    private func screen(_ model: AssignViewModel) -> some View {
        NavigationStack { AssignScreen(model: model) }
            .environment(AppRouter())
    }

    @Test func nothingMarkedYet() {
        assertDesignSnapshot(screen(model(AssignSamples.table())), named: "nothing-marked", fixedHeight: 844)
    }

    @Test func sixOfEightMarkedWithTwoUnassignedFlagged() {
        assertDesignSnapshot(screen(model(SampleBill.midway())), named: "midway", fixedHeight: 844)
    }

    @Test func reviewSplitWithItemsLeftWarnsAndOffersToSplitTheRest() {
        let model = model(SampleBill.midway())
        _ = model.reviewSplit()
        assertDesignSnapshot(screen(model), named: "warning", fixedHeight: 844)
    }

    @Test func paintModeForOnePerson() {
        let model = model(SampleBill.midway())
        model.togglePainting(AssignSamples.personID(3))
        assertDesignSnapshot(screen(model), named: "paint", fixedHeight: 844)
    }

    @Test func everythingMarked() {
        assertDesignSnapshot(screen(model(SampleBill.complete())), named: "complete", fixedHeight: 844)
    }

    @Test func aQuantityLineMarkedUnitByUnit() {
        let model = model(AssignSamples.quantities())
        model.toggle(AssignSamples.personID(1), on: AssignSamples.quantityItemID(1), scope: .unit(0))
        model.toggle(AssignSamples.personID(2), on: AssignSamples.quantityItemID(1), scope: .unit(1))
        model.toggle(AssignSamples.personID(1), on: AssignSamples.quantityItemID(3))
        model.toggle(AssignSamples.personID(3), on: AssignSamples.quantityItemID(3))
        assertDesignSnapshot(screen(model), named: "quantities", fixedHeight: 844)
    }

    @Test func nineFriendsKeepTheirColoursAndTheChipsScroll() {
        var session = AssignSamples.table()
        for name in ["Ana", "Bo", "Carmen", "Dalila", "Eduardo"] { session.addParticipant(name: name) }
        let model = model(session)
        model.toggleEveryone(on: AssignSamples.itemID(8))
        assertDesignSnapshot(screen(model), named: "nine-people", fixedHeight: 844)
    }

    @Test func sheetForAnItemSplitThreeWaysShowsTheExtraCents() {
        let model = model(AssignSamples.table())
        let surtido = AssignSamples.itemID(3)
        for number in 1 ... 3 { model.toggle(AssignSamples.personID(number), on: surtido) }
        model.tapRow(surtido)
        assertDesignSnapshot(AssignSheet(model: model), named: "sheet-shared", fixedHeight: 640)
    }

    @Test func sheetForAnItemNobodyHasYetAsksForAtLeastOnePerson() {
        let model = model(AssignSamples.table())
        model.tapRow(AssignSamples.itemID(4))
        assertDesignSnapshot(AssignSheet(model: model), named: "sheet-empty", fixedHeight: 640)
    }

    @Test func sheetForAQuantityLineHasTheUnitPicker() {
        let model = model(AssignSamples.quantities())
        let medalla = AssignSamples.quantityItemID(1)
        model.toggle(AssignSamples.personID(2), on: medalla, scope: .unit(1))
        model.tapRow(medalla)
        model.selectScope(.unit(1))
        assertDesignSnapshot(AssignSheet(model: model), named: "sheet-unit", fixedHeight: 720)
    }
}
