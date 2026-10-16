import EsplitealoCore
import Foundation
import Observation

/// Which units of a quantity line an edit applies to: all of them, or one.
enum AssignScope: Hashable {
    case all
    case unit(Int)
}

/// The logic of the Mark items screen: who had what, the live per-person pre-tax subtotals, quantity lines marked
/// unit by unit, the unassigned block, "split the rest evenly", paint mode and the assign sheet. It reads the bill
/// from the `BillStore` and changes it only through `store.update`, so every edit is autosaved.
///
/// "Items" are counted in units: a ×3 line is three things to mark, and a bill whose lines are all single units
/// counts exactly as the mockups do ("6 de 8").
@MainActor @Observable
final class AssignViewModel {
    @ObservationIgnored private let store: BillStore

    init(store: BillStore) {
        self.store = store
    }

    // MARK: Reading the bill

    private var session: BillSession? { store.session }
    private var participants: [Participant] { session?.participants ?? [] }

    struct Person: Identifiable, Equatable {
        let id: UUID
        let name: String
        /// The person's colour: their position at the table (see `PersonColorSlot`).
        let colorIndex: Int
        /// Their share of everything marked so far, before tax and tip.
        let subtotalCents: Int
        let isPainting: Bool
    }

    /// The chips: everyone at the table with their live pre-tax subtotal.
    var people: [Person] {
        guard let session else { return [] }
        let subtotals = Dictionary(
            session.personBreakdowns.map { ($0.participantID, $0.itemSubtotalCents) },
            uniquingKeysWith: { first, _ in first }
        )
        return session.participants.enumerated().map { index, person in
            Person(
                id: person.id,
                name: person.name,
                colorIndex: index,
                subtotalCents: subtotals[person.id] ?? 0,
                isPainting: person.id == paintingID
            )
        }
    }

    struct Unit: Equatable {
        let index: Int
        let priceCents: Int
        /// Who is marked for this unit, in table order.
        let assigneeIDs: [UUID]
        /// Each marked person's share of this unit's price.
        let sharesCents: [UUID: Int]
    }

    struct Row: Identifiable, Equatable {
        enum State: Equatable {
            case unassigned, partlyAssigned, assigned
        }

        let id: UUID
        let name: String
        let quantity: Int
        let totalCents: Int
        let units: [Unit]
        /// Everyone at the table, in order.
        let tableOrder: [UUID]

        /// Everyone marked for at least one unit, in table order.
        var assigneeIDs: [UUID] {
            let marked = Set(units.flatMap(\.assigneeIDs))
            return tableOrder.filter(marked.contains)
        }
        var unassignedUnitCount: Int { units.filter { $0.assigneeIDs.isEmpty }.count }
        var unassignedCents: Int { units.filter { $0.assigneeIDs.isEmpty }.reduce(0) { $0 + $1.priceCents } }

        var state: State {
            switch unassignedUnitCount {
            case 0: .assigned
            case units.count: .unassigned
            default: .partlyAssigned
            }
        }

        /// Each person's share of the whole line.
        var personShares: [UUID: Int] {
            units.reduce(into: [:]) { totals, unit in
                for (id, cents) in unit.sharesCents { totals[id, default: 0] += cents }
            }
        }

        /// Every unit has the same people, so the line can be described in one phrase.
        var hasSamePeopleOnEveryUnit: Bool {
            guard let first = units.first else { return true }
            return units.allSatisfy { $0.assigneeIDs == first.assigneeIDs }
        }

        func unitCount(markedFor id: UUID) -> Int {
            units.filter { $0.assigneeIDs.contains(id) }.count
        }
    }

    /// One row per receipt line, in receipt order.
    var rows: [Row] {
        guard let session else { return [] }
        let tableOrder = session.participants.map(\.id)
        return session.draft.items.map { item in
            let line = LineSplit(item: item, participants: session.participants)
            let units = (0 ..< item.quantity).map { index -> Unit in
                let marked = tableOrder.filter { assignees(item.id, index, in: session).contains($0) }
                let priced = line.unit(index, assignedTo: marked)
                return Unit(index: index, priceCents: priced.priceCents, assigneeIDs: marked, sharesCents: priced.sharesCents)
            }
            return Row(id: item.id, name: item.name, quantity: item.quantity, totalCents: item.lineTotal.minorUnits, units: units, tableOrder: tableOrder)
        }
    }

    // MARK: Progress

    var totalUnitCount: Int { rows.reduce(0) { $0 + $1.units.count } }
    var unassignedUnitCount: Int { session?.unassignedUnits.count ?? 0 }
    var assignedUnitCount: Int { totalUnitCount - unassignedUnitCount }
    var unassignedCents: Int { rows.reduce(0) { $0 + $1.unassignedCents } }
    var isComplete: Bool { unassignedUnitCount == 0 }

    // MARK: Marking

    /// Puts the person on every unit in `scope`, or takes them off every one when they already have them all.
    func toggle(_ personID: UUID, on itemID: UUID, scope: AssignScope = .all) {
        guard let units = unitIndexes(of: itemID, in: scope), participants.contains(where: { $0.id == personID }) else { return }
        store.update { session in
            let hasAll = units.allSatisfy { assignees(itemID, $0, in: session).contains(personID) }
            for unit in units {
                var marked = assignees(itemID, unit, in: session)
                if hasAll {
                    marked.removeAll { $0 == personID }
                } else if !marked.contains(personID) {
                    marked.append(personID)
                }
                session.assignUnit(itemID: itemID, unitIndex: unit, participantIDs: marked)
            }
        }
        didEdit()
    }

    /// Marks everyone at the table for the units in `scope`, or clears them when everyone already has them all.
    func toggleEveryone(on itemID: UUID, scope: AssignScope = .all) {
        guard let units = unitIndexes(of: itemID, in: scope) else { return }
        let everyone = participants.map(\.id)
        store.update { session in
            let hasAll = units.allSatisfy { Set(assignees(itemID, $0, in: session)) == Set(everyone) }
            for unit in units {
                if hasAll {
                    session.clearUnitAssignment(itemID: itemID, unitIndex: unit)
                } else {
                    session.assignUnit(itemID: itemID, unitIndex: unit, participantIDs: everyone)
                }
            }
        }
        didEdit()
    }

    func clear(_ itemID: UUID, scope: AssignScope = .all) {
        guard let units = unitIndexes(of: itemID, in: scope) else { return }
        store.update { session in
            for unit in units { session.clearUnitAssignment(itemID: itemID, unitIndex: unit) }
        }
        didEdit()
    }

    /// Gives every unit nobody has to everyone at the table, in equal parts. Units that already have people are left
    /// alone. One tap: the screen asks nothing first, because the button says exactly what it does.
    func splitRestEvenly() {
        store.update { $0.splitRestEvenly() }
        didEdit()
    }

    // MARK: Review split

    enum ReviewOutcome: Equatable {
        case proceed
        case blocked(unassignedUnitCount: Int)
    }

    private var warned = false

    /// The warning banner under the header: shown after Review split was tapped with items left, until the last one
    /// is marked.
    var showsWarning: Bool { warned && !isComplete }

    /// Review split stays tappable: with items left it explains instead of moving on.
    func reviewSplit() -> ReviewOutcome {
        let left = unassignedUnitCount
        guard left > 0 else {
            warned = false
            return .proceed
        }
        warned = true
        paintingID = nil
        return .blocked(unassignedUnitCount: left)
    }

    private func didEdit() {
        if isComplete { warned = false }
    }

    // MARK: Paint mode

    private(set) var paintingID: UUID?

    /// Tap a name, then tap items: each tap marks or unmarks that person. Tapping the same name again stops.
    func togglePainting(_ personID: UUID) {
        guard participants.contains(where: { $0.id == personID }) else { return }
        paintingID = paintingID == personID ? nil : personID
        if paintingID != nil { sheetState = nil }
    }

    /// A tap on an item row: paints it while painting, otherwise opens its sheet.
    func tapRow(_ itemID: UUID) {
        if let painter = paintingID, participants.contains(where: { $0.id == painter }) {
            toggle(painter, on: itemID)
        } else {
            openSheet(itemID)
        }
    }

    // MARK: VoiceOver actions

    enum RowAction: Hashable {
        case mark(UUID)
        case unmark(UUID)
        case markEveryone
        case clear
    }

    /// What VoiceOver offers on a row besides opening the sheet: mark or unmark each person (for the whole line),
    /// everyone, and clearing.
    func actions(for itemID: UUID) -> [RowAction] {
        guard let row = rows.first(where: { $0.id == itemID }) else { return [] }
        var actions = participants.map { person -> RowAction in
            row.unitCount(markedFor: person.id) == row.units.count ? .unmark(person.id) : .mark(person.id)
        }
        let everyoneHasAll = participants.allSatisfy { row.unitCount(markedFor: $0.id) == row.units.count }
        if !everyoneHasAll { actions.append(.markEveryone) }
        if row.state != .unassigned { actions.append(.clear) }
        return actions
    }

    func perform(_ action: RowAction, on itemID: UUID) {
        switch action {
        case let .mark(id), let .unmark(id): toggle(id, on: itemID)
        case .markEveryone: toggleEveryone(on: itemID) // only offered while someone is still missing
        case .clear: clear(itemID)
        }
    }

    // MARK: The assign sheet

    struct Sheet: Equatable, Identifiable {
        let itemID: UUID
        var scope: AssignScope
        var id: UUID { itemID }
    }

    private var sheetState: Sheet?

    /// The open sheet, or nil when none is open or its item has gone.
    var sheet: Sheet? {
        guard let sheetState, session?.draft.items.contains(where: { $0.id == sheetState.itemID }) == true else { return nil }
        return sheetState
    }

    func openSheet(_ itemID: UUID) {
        guard session?.draft.items.contains(where: { $0.id == itemID }) == true else { return }
        sheetState = Sheet(itemID: itemID, scope: .all)
    }

    func closeSheet() {
        sheetState = nil
    }

    func selectScope(_ scope: AssignScope) {
        sheetState?.scope = scope
    }

    enum SheetMark: Equatable {
        case none
        /// A quantity line, whole-line view: marked for this many of its units.
        case some(Int)
        case all
    }

    struct SheetPerson: Identifiable, Equatable {
        let id: UUID
        let name: String
        let colorIndex: Int
        let mark: SheetMark
        /// What this person pays of the item (or of the unit) when marked.
        let shareCents: Int?
    }

    /// What the sheet says under the people.
    enum SheetNote: Equatable {
        case pickOne
        case all
        case split(ways: Int)
        /// An uneven split: the cents left over and who pays the extra cent (list order).
        case leftover(ways: Int, cents: Int, names: [String])
        /// A quantity line whose units have different people.
        case mixed
        /// A quantity line, whole-line view, with some units still unmarked.
        case incomplete(left: Int, of: Int)
    }

    struct SheetContent: Equatable {
        let itemName: String
        let unitCount: Int
        let scope: AssignScope
        /// The price of the line, or of the picked unit.
        let totalCents: Int
        let people: [SheetPerson]
        let note: SheetNote
        /// Everyone at the table is marked for every unit in scope: the shortcut reads "Ninguno" instead of "Todos".
        let everyoneSelected: Bool
    }

    var sheetContent: SheetContent? {
        guard let sheet, let row = rows.first(where: { $0.id == sheet.itemID }) else { return nil }
        let units = unitsInScope(sheet.scope, of: row)
        let scope: AssignScope = units.count == row.units.count ? .all : sheet.scope
        let people = participants.enumerated().map { index, person -> SheetPerson in
            let marked = units.filter { $0.assigneeIDs.contains(person.id) }
            let mark: SheetMark = marked.isEmpty ? .none : marked.count == units.count ? .all : .some(marked.count)
            let share = marked.isEmpty ? nil : marked.reduce(0) { $0 + ($1.sharesCents[person.id] ?? 0) }
            return SheetPerson(id: person.id, name: person.name, colorIndex: index, mark: mark, shareCents: share)
        }
        return SheetContent(
            itemName: row.name,
            unitCount: row.units.count,
            scope: scope,
            totalCents: units.reduce(0) { $0 + $1.priceCents },
            people: people,
            note: note(for: units, people: people, row: row),
            everyoneSelected: !people.isEmpty && people.allSatisfy { $0.mark == .all }
        )
    }

    private func unitsInScope(_ scope: AssignScope, of row: Row) -> [Unit] {
        if case let .unit(index) = scope, row.units.indices.contains(index) { return [row.units[index]] }
        return row.units
    }

    private func note(for units: [Unit], people: [SheetPerson], row: Row) -> SheetNote {
        let unmarked = units.filter { $0.assigneeIDs.isEmpty }.count
        if unmarked == units.count { return .pickOne }
        if unmarked > 0 { return .incomplete(left: unmarked, of: units.count) }
        let first = units[0]
        guard units.allSatisfy({ $0.assigneeIDs == first.assigneeIDs }) else { return .mixed }
        let ways = first.assigneeIDs.count
        if ways == 1 { return .all }
        let leftover = first.priceCents % ways
        // The cents left over are only worth a sentence when a single unit is on screen.
        guard units.count == 1, leftover > 0 else { return .split(ways: ways) }
        let top = first.sharesCents.values.max()
        let names = people.filter { first.sharesCents[$0.id] == top }.map(\.name)
        return .leftover(ways: ways, cents: leftover, names: names)
    }

    // MARK: Internals

    private func unitIndexes(of itemID: UUID, in scope: AssignScope) -> [Int]? {
        guard let item = session?.draft.items.first(where: { $0.id == itemID }) else { return nil }
        if case let .unit(index) = scope, (0 ..< item.quantity).contains(index) { return [index] }
        return Array(0 ..< item.quantity)
    }

    private func assignees(_ itemID: UUID, _ unit: Int, in session: BillSession) -> [UUID] {
        session.assignments.first { $0.itemID == itemID && $0.unitIndex == unit }?.participantIDs ?? []
    }
}
