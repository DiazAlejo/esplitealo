import XCTest
@testable import EsplitealoCore

final class BillSessionAssignmentTests: XCTestCase {
    func testAssignItemEqualSplitDefault() {
        var session = BillSession.sampleTwoPeopleOneItem()
        let item = session.draft.items[0]
        let a = session.participants[0]
        let b = session.participants[1]
        session.assignUnit(itemID: item.id, unitIndex: 0, participantIDs: [a.id, b.id])
        let assignment = session.assignments.first { $0.itemID == item.id && $0.unitIndex == 0 }
        XCTAssertEqual(Set(assignment?.participantIDs ?? []), Set([a.id, b.id]))
        XCTAssertEqual(session.preTaxSubtotalCents(for: a.id), 600)
        XCTAssertEqual(session.preTaxSubtotalCents(for: b.id), 600)
    }

    func testQuantityLinePerUnitAssignment() {
        var session = BillSession.sampleTwoPeopleQuantityLine()
        let item = session.draft.items[0]
        let a = session.participants[0]
        let b = session.participants[1]
        session.assignUnit(itemID: item.id, unitIndex: 0, participantIDs: [a.id])
        session.assignUnit(itemID: item.id, unitIndex: 1, participantIDs: [b.id])
        XCTAssertEqual(session.preTaxSubtotalCents(for: a.id), 1200)
        XCTAssertEqual(session.preTaxSubtotalCents(for: b.id), 1200)
    }

    func testUnassignedDetection() {
        var session = BillSession.sampleTwoPeopleOneItem()
        XCTAssertEqual(session.unassignedUnits.count, 1)
        session.splitRestEvenly()
        XCTAssertTrue(session.unassignedUnits.isEmpty)
    }

    func testSplitRestEvenlyAssignsAllParticipants() {
        var session = BillSession.sampleTwoPeopleOneItem()
        session.splitRestEvenly()
        let item = session.draft.items[0]
        let ids = session.assignments.first { $0.itemID == item.id }?.participantIDs ?? []
        XCTAssertEqual(Set(ids), Set(session.participants.map(\.id)))
    }
}
