import Foundation

extension BillSession {
    static func sampleReadyToShare() -> BillSession {
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let samID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let alexItem = DraftItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Alex plate",
            quantity: 1,
            lineTotal: DraftAmount(minorUnits: 6000)
        )
        let samItem = DraftItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Sam plate",
            quantity: 1,
            lineTotal: DraftAmount(minorUnits: 4000)
        )
        var draft = ReceiptDraft(
            items: [alexItem, samItem],
            subtotal: DraftAmount(minorUnits: 10_000),
            tax: DraftAmount(minorUnits: 1000),
            total: DraftAmount(minorUnits: 11_000)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        let alex = Participant(id: alexID, name: "Alex", orderIndex: 0)
        let sam = Participant(id: samID, name: "Sam", orderIndex: 1)
        return BillSession(
            draft: draft,
            merchantName: "Fonda Doña Lola",
            dateLabel: "13 oct",
            dateLabelEnglish: "Oct 13",
            participants: [alex, sam],
            assignments: [
                ItemAssignment(itemID: alexItem.id, unitIndex: 0, participantIDs: [alexID]),
                ItemAssignment(itemID: samItem.id, unitIndex: 0, participantIDs: [samID]),
            ],
            tip: .percentage(percent: 20, basis: .preTaxSubtotal)
        )
    }

    static func sampleTwoPeopleOneItem() -> BillSession {
        var session = BillSession(draft: ReceiptDraft(
            items: [DraftItem(name: "Shared", quantity: 1, lineTotal: DraftAmount(minorUnits: 1200))]
        ))
        _ = session.addParticipant(name: "A")
        _ = session.addParticipant(name: "B")
        return session
    }

    static func sampleTwoPeopleQuantityLine() -> BillSession {
        var session = BillSession(draft: ReceiptDraft(
            items: [DraftItem(name: "Entrée", quantity: 2, lineTotal: DraftAmount(minorUnits: 2400))]
        ))
        _ = session.addParticipant(name: "A")
        _ = session.addParticipant(name: "B")
        return session
    }

    static func sampleAssigned() -> BillSession {
        var session = sampleTwoPeopleOneItem()
        _ = session.addParticipant(name: "C")
        let item = session.draft.items[0]
        session.assignUnit(itemID: item.id, unitIndex: 0, participantIDs: [session.participants[0].id, session.participants[1].id])
        return session
    }

    static func sampleMismatch() -> BillSession {
        var draft = ReceiptDraft(
            items: [DraftItem(name: "A", quantity: 1, lineTotal: DraftAmount(minorUnits: 500))],
            subtotal: DraftAmount(minorUnits: 500),
            total: DraftAmount(minorUnits: 900)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        var session = BillSession(draft: draft)
        _ = session.addParticipant(name: "Alex")
        return session
    }

    static func sampleMismatchFullyAssigned() -> BillSession {
        var session = sampleMismatch()
        let item = session.draft.items[0]
        session.assignUnit(itemID: item.id, unitIndex: 0, participantIDs: [session.participants[0].id])
        return session
    }

    static func sampleReadyToShareWithPrintedTip() -> BillSession {
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let samID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let alexItem = DraftItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Alex plate",
            quantity: 1,
            lineTotal: DraftAmount(minorUnits: 6000)
        )
        let samItem = DraftItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Sam plate",
            quantity: 1,
            lineTotal: DraftAmount(minorUnits: 4000)
        )
        var draft = ReceiptDraft(
            items: [alexItem, samItem],
            subtotal: DraftAmount(minorUnits: 10_000),
            tax: DraftAmount(minorUnits: 1000),
            tip: DraftAmount(minorUnits: 2000),
            total: DraftAmount(minorUnits: 13_000)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        let alex = Participant(id: alexID, name: "Alex", orderIndex: 0)
        let sam = Participant(id: samID, name: "Sam", orderIndex: 1)
        return BillSession(
            draft: draft,
            merchantName: "Fonda Doña Lola",
            dateLabel: "13 oct",
            dateLabelEnglish: "Oct 13",
            participants: [alex, sam],
            assignments: [
                ItemAssignment(itemID: alexItem.id, unitIndex: 0, participantIDs: [alexID]),
                ItemAssignment(itemID: samItem.id, unitIndex: 0, participantIDs: [samID]),
            ],
            tip: .percentage(percent: 0, basis: .preTaxSubtotal)
        )
    }

    static func sampleWithServiceCharge() -> BillSession {
        var draft = ReceiptDraft(
            items: [DraftItem(name: "Plate", quantity: 1, lineTotal: DraftAmount(minorUnits: 10_100))],
            subtotal: DraftAmount(minorUnits: 10_100),
            tax: DraftAmount(minorUnits: 1162),
            tip: DraftAmount(minorUnits: 1515),
            total: DraftAmount(minorUnits: 12_777)
        )
        draft = ReceiptDraftEditing.reconcile(draft)
        return BillSession(
            draft: draft,
            serviceChargeCents: 1515
        )
    }

    static func sampleWithServiceChargeAssigned() -> BillSession {
        var session = sampleWithServiceCharge()
        _ = session.addParticipant(name: "Alex")
        _ = session.addParticipant(name: "Sam")
        let item = session.draft.items[0]
        session.assignUnit(itemID: item.id, unitIndex: 0, participantIDs: [session.participants[0].id, session.participants[1].id])
        session.tip = .percentage(percent: 0, basis: .preTaxSubtotal)
        return session
    }
}
