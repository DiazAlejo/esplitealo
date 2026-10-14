import XCTest
@testable import EsplitealoCore

final class BillSessionParticipantsTests: XCTestCase {
    func testRequiresAtLeastOneParticipant() {
        var session = BillSession(draft: ReceiptDraft())
        XCTAssertEqual(session.addParticipant(name: "Alex"), .added)
        XCTAssertEqual(session.removeParticipant(id: session.participants[0].id), .lastParticipant)
    }

    func testRemoveParticipantWithAssignmentsRequiresConfirmation() {
        var session = BillSession.sampleAssigned()
        let target = session.participants[1]
        let result = session.removeParticipant(id: target.id)
        guard case let .requiresConfirmation(count, _, sharedRemains) = result else {
            return XCTFail("expected confirmation")
        }
        XCTAssertGreaterThan(count, 0)
        XCTAssertTrue(sharedRemains)
        XCTAssertEqual(session.participants.count, 3)
    }

    func testForceRemoveParticipantStripsAssignments() {
        var session = BillSession.sampleAssigned()
        let target = session.participants[1]
        session.forceRemoveParticipant(id: target.id)
        XCTAssertEqual(session.participants.count, 2)
        XCTAssertFalse(session.assignments.contains { $0.participantIDs.contains(target.id) })
    }

    func testRenameParticipant() {
        var session = BillSession(draft: ReceiptDraft())
        _ = session.addParticipant(name: "A")
        let id = session.participants[0].id
        session.renameParticipant(id: id, name: "Alex")
        XCTAssertEqual(session.participants[0].name, "Alex")
    }
}
