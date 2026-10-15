import EsplitealoCore
import Foundation

/// The Fonda Doña Lola bill from the mockups, for previews, tests and the UI-test fixture. Fixed identifiers, so
/// snapshots and equality checks are stable.
enum SampleBill {
    static let merchantName = "Fonda Doña Lola"
    static let people = ["Marisol", "Héctor", "Keishla", "Yadiel"]

    private static let items: [(name: String, cents: Int)] = [
        ("Jugo de parcha", 400), ("Medalla", 500), ("Surtido de frituras", 1400), ("Mofongo de camarones", 2200),
        ("Pernil con gandules", 1800), ("Ensalada de pulpo", 1400), ("Bistec encebollado", 1500), ("Flan para compartir", 900),
    ]

    private static func itemID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", number))!
    }

    private static func personID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
    }

    /// The receipt as scanned and fixed: 8 items, $101.00 subtotal, $11.62 tax, $112.62 total.
    static func scannedDraft() -> ReceiptDraft {
        ReceiptDraft(
            items: items.enumerated().map { index, item in
                DraftItem(id: itemID(index + 1), name: item.name, quantity: 1, lineTotal: DraftAmount(minorUnits: item.cents))
            },
            subtotal: DraftAmount(minorUnits: 10_100),
            tax: DraftAmount(minorUnits: 1162),
            total: DraftAmount(minorUnits: 11_262)
        )
    }

    /// A fresh scan: items, nobody at the table yet.
    static func scanned() -> BillSession {
        BillSession(draft: scannedDraft(), merchantName: merchantName, date: Date(timeIntervalSince1970: 1_791_892_800))
    }

    /// Four friends, 6 of 8 items assigned.
    static func midway() -> BillSession {
        var session = scanned()
        for (index, name) in people.enumerated() {
            session.participants.append(Participant(id: personID(index + 1), name: name, orderIndex: index))
        }
        let who: [Int: [Int]] = [2: [2], 3: [1, 2, 3], 4: [1], 5: [2], 6: [3], 7: [4]]
        for (item, persons) in who {
            session.assignUnit(itemID: itemID(item), unitIndex: 0, participantIDs: persons.map(personID))
        }
        return session
    }

    /// Everything assigned.
    static func complete() -> BillSession {
        var session = midway()
        session.assignUnit(itemID: itemID(1), unitIndex: 0, participantIDs: [personID(4)])
        session.assignUnit(itemID: itemID(8), unitIndex: 0, participantIDs: (1 ... 4).map(personID))
        return session
    }
}
