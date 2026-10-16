import EsplitealoCore
import Foundation

/// How one receipt line is priced and shared out among the people marked for each of its units.
///
/// The numbers come from `BillCalculator` itself (the calculator proven against an independent reference), asked
/// about this single line, so the screen can never disagree with the totals: the unit prices, the equal split of a
/// unit and the person who gets the leftover cent are the calculator's own.
struct LineSplit {
    let item: DraftItem
    let participants: [Participant]

    /// Price of one unit and each marked person's share of it, in cents. A unit nobody is marked for still has its
    /// price, found by asking the calculator to share it among everyone.
    func unit(_ index: Int, assignedTo assigneeIDs: [UUID]) -> (priceCents: Int, sharesCents: [UUID: Int]) {
        let marked = assigneeIDs.filter { id in participants.contains { $0.id == id } }
        if !marked.isEmpty {
            let shares = shares(of: [ItemAssignment(itemID: item.id, unitIndex: index, participantIDs: marked)], among: participants)
            return (shares.values.reduce(0, +), shares)
        }
        // With nobody at the table (not reachable from the flow) a stand-in person lets the calculator price the unit.
        let probe = participants.isEmpty ? [Participant(name: "", orderIndex: 0)] : participants
        let everyone = ItemAssignment(itemID: item.id, unitIndex: index, participantIDs: probe.map(\.id))
        return (shares(of: [everyone], among: probe).values.reduce(0, +), [:])
    }

    private func shares(of assignments: [ItemAssignment], among people: [Participant]) -> [UUID: Int] {
        let line = ReceiptItem(id: item.id, description: item.name, quantity: item.quantity, totalPriceCents: item.lineTotal.minorUnits)
        let receipt = Receipt(
            items: [line],
            taxCents: 0,
            tip: .custom(cents: 0),
            confirmedTotalCents: item.lineTotal.minorUnits,
            participants: people,
            assignments: assignments
        )
        let result = BillCalculator().calculate(receipt: receipt)
        return Dictionary(
            result.shares.filter { $0.itemSubtotalCents > 0 }.map { ($0.participantID, $0.itemSubtotalCents) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
