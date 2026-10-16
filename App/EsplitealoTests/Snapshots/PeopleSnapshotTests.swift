import EsplitealoCore
import SwiftUI
import Testing
@testable import Esplitealo

/// The Add people screen and its sheets: the empty table with Chavito, four friends, and the two sheets.
@MainActor
struct PeopleSnapshotTests {
    private func store(_ session: BillSession) -> BillStore {
        let store = BillStore(draftStore: RecordingDraftStore(), clock: ManualClock())
        store.startNewBill(draft: session.draft)
        store.update { $0 = session }
        return store
    }

    private func screen(_ store: BillStore) -> some View {
        NavigationStack { PeopleView() }
            .environment(store)
            .environment(AppRouter())
    }

    @Test func emptyTableWithChavito() {
        assertDesignSnapshot(screen(store(SampleBill.scanned())), named: "empty", fixedHeight: 844)
    }

    @Test func fourFriendsWithTheirItems() {
        assertDesignSnapshot(screen(store(SampleBill.midway())), named: "four-people", fixedHeight: 844)
    }

    @Test func nineAndLongNamesKeepTheirColoursAndWrap() {
        var session = SampleBill.scanned()
        for name in ["Marisol Fernández", "Héctor", "Keishla", "Yadiel", "Ana", "Bo", "Carmen", "Dalila", "Eduardo"] {
            session.addParticipant(name: name)
        }
        assertDesignSnapshot(screen(store(session)), named: "nine-people", fixedHeight: 1400)
    }

    @Test func renameSheet() {
        let store = store(SampleBill.midway())
        let model = PeopleViewModel(store: store)
        model.beginRename(id: store.session!.participants[1].id)
        assertDesignSnapshot(RenameSheet(model: model), named: "rename", fixedHeight: 300)
    }

    @Test func removeSheetWithItemsMarked() throws {
        let store = store(SampleBill.midway())
        let model = PeopleViewModel(store: store)
        model.requestRemoval(id: store.session!.participants[1].id)
        let removal = try #require(model.pendingRemoval)
        assertDesignSnapshot(RemovePersonSheet(removal: removal, onKeep: {}, onRemove: {}), named: "remove", fixedHeight: 300)
    }
}
