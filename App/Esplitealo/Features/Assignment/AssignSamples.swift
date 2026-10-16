import EsplitealoCore
import Foundation

/// Bills for the Mark items screen's previews, snapshot tests and UI-test fixtures: people already at the table and
/// the items still to mark. Identifiers match `SampleBill`, so its items and people line up with these.
enum AssignSamples {
    static func personID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
    }

    /// Items of `SampleBill` (the Fonda Doña Lola receipt).
    static func itemID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", number))!
    }

    /// Items of `quantities()`.
    static func quantityItemID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", number))!
    }

    /// The scanned and fixed receipt with the four friends at the table and nothing marked yet.
    static func table() -> BillSession {
        var session = SampleBill.midway()
        session.assignments = []
        return session
    }

    /// Three friends and a receipt with lines of several units: 3 Medallas ($15.00), a mofongo, 2 tostones that cost
    /// $7.01 in all (an odd cent, so the units differ by one cent), and a flan. Nothing marked yet.
    static func quantities() -> BillSession {
        func item(_ number: Int, _ name: String, quantity: Int, cents: Int) -> DraftItem {
            DraftItem(
                id: quantityItemID(number),
                name: name,
                quantity: quantity,
                lineTotal: DraftAmount(minorUnits: cents),
                unitPrice: quantity > 1 && cents % quantity == 0 ? DraftAmount(minorUnits: cents / quantity) : nil
            )
        }
        let draft = ReceiptDraft(
            items: [
                item(1, "Medalla", quantity: 3, cents: 1500),
                item(2, "Mofongo de camarones", quantity: 1, cents: 2200),
                item(3, "Tostones", quantity: 2, cents: 701),
                item(4, "Flan para compartir", quantity: 1, cents: 900),
            ],
            subtotal: DraftAmount(minorUnits: 5301),
            tax: DraftAmount(minorUnits: 610),
            total: DraftAmount(minorUnits: 5911)
        )
        var session = BillSession(draft: draft, merchantName: SampleBill.merchantName, date: Date(timeIntervalSince1970: 1_791_892_800))
        for (index, name) in SampleBill.people.prefix(3).enumerated() {
            session.participants.append(Participant(id: personID(index + 1), name: name, orderIndex: index))
        }
        return session
    }
}
