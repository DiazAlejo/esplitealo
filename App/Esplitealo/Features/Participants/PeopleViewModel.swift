import EsplitealoCore
import Foundation
import Observation

/// The logic of the Add people screen: names, the table, and removing someone who already has items marked. It reads
/// the bill from the `BillStore` and changes it only through `store.update`, so every edit is autosaved.
@MainActor @Observable
final class PeopleViewModel {
    static let maxNameLength = 18

    /// What the screen tells the user about the name they typed (or the removal they asked for).
    enum Message: Equatable {
        case nameMissing
        case duplicate(String)
        case lastPerson
    }

    struct Row: Identifiable, Equatable {
        let id: UUID
        let name: String
        /// The person's colour: their position at the table (see `PersonColorSlot`).
        let colorIndex: Int
        /// Items with at least one unit marked for this person.
        let assignedItemCount: Int
    }

    /// What removing someone would do, shown before anything changes.
    struct Removal: Equatable, Identifiable {
        let id: UUID
        let name: String
        let assignedItemCount: Int
        /// Items that only this person had: they go back to unassigned.
        let orphanedItemNames: [String]
        /// Some items are shared, and the others keep them.
        let sharedItemsRemain: Bool
    }

    @ObservationIgnored private let store: BillStore

    init(store: BillStore) {
        self.store = store
    }

    func startBillIfNeeded() {
        if store.session == nil { store.startNewBill() }
    }

    // MARK: The table

    private var participants: [Participant] { store.session?.participants ?? [] }

    var rows: [Row] {
        let assignments = store.session?.assignments ?? []
        return participants.enumerated().map { index, person in
            let items = Set(assignments.filter { $0.participantIDs.contains(person.id) }.map(\.itemID))
            return Row(id: person.id, name: person.name, colorIndex: index, assignedItemCount: items.count)
        }
    }

    /// Continuing needs at least one person.
    var canContinue: Bool { !participants.isEmpty }

    // MARK: Adding

    private var typedName = ""
    private(set) var message: Message?

    var nameDraft: String {
        get { typedName }
        set {
            typedName = String(newValue.prefix(Self.maxNameLength))
            message = nil
        }
    }

    func addPerson() {
        let name = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            message = .nameMissing
            return
        }
        guard !isTaken(name, excluding: nil) else {
            message = .duplicate(name)
            return
        }
        store.update { $0.addParticipant(name: name) }
        typedName = ""
        message = nil
    }

    private func isTaken(_ name: String, excluding id: UUID?) -> Bool {
        participants.contains { person in
            person.id != id && person.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    // MARK: Renaming

    private(set) var renaming: Participant?
    private(set) var renameMessage: Message?
    private var typedRename = ""

    var renameDraft: String {
        get { typedRename }
        set {
            typedRename = String(newValue.prefix(Self.maxNameLength))
            renameMessage = nil
        }
    }

    func beginRename(id: UUID) {
        guard let person = participants.first(where: { $0.id == id }) else { return }
        renaming = person
        typedRename = person.name
        renameMessage = nil
    }

    /// Returns whether the name was accepted; when it was not, `renameMessage` says why and the sheet stays open.
    @discardableResult
    func commitRename() -> Bool {
        guard let person = renaming else { return false }
        let name = typedRename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            renameMessage = .nameMissing
            return false
        }
        guard !isTaken(name, excluding: person.id) else {
            renameMessage = .duplicate(name)
            return false
        }
        store.update { $0.renameParticipant(id: person.id, name: name) }
        cancelRename()
        return true
    }

    func cancelRename() {
        renaming = nil
        renameMessage = nil
        typedRename = ""
    }

    // MARK: Removing

    private(set) var pendingRemoval: Removal?

    /// Removes the person at once when nothing is marked for them; otherwise asks first. The last person stays.
    func requestRemoval(id: UUID) {
        guard let session = store.session, let person = participants.first(where: { $0.id == id }) else { return }
        message = nil
        var trial = session
        switch trial.removeParticipant(id: id) {
        case .removed:
            store.update { _ = $0.removeParticipant(id: id) }
        case .lastParticipant:
            message = .lastPerson
        case .notFound:
            break
        case let .requiresConfirmation(_, _, sharedAssignmentsRemain):
            let assigned = session.assignments.filter { $0.participantIDs.contains(id) }
            let orphanedItemIDs = Set(assigned.filter { $0.participantIDs == [id] }.map(\.itemID))
            pendingRemoval = Removal(
                id: id,
                name: person.name,
                assignedItemCount: Set(assigned.map(\.itemID)).count,
                orphanedItemNames: session.draft.items.filter { orphanedItemIDs.contains($0.id) }.map(\.name),
                sharedItemsRemain: sharedAssignmentsRemain
            )
        }
    }

    func confirmRemoval() {
        guard let removal = pendingRemoval else { return }
        store.update { $0.forceRemoveParticipant(id: removal.id) }
        pendingRemoval = nil
    }

    func cancelRemoval() {
        pendingRemoval = nil
    }
}
