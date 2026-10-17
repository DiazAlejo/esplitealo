import XCTest
@testable import EsplitealoCore
#if canImport(Darwin)
import Darwin
#endif

/// A big table: 40 receipt lines (some of several units) and 8 people. Nobody should wait for it and it should not
/// grow the process. The limits are far above what a phone needs (a full pass takes a few milliseconds) so a slow
/// CI machine cannot make them flaky, and far below anything a person would notice, so an accidental quadratic
/// loop or a leak still fails them.
final class LargeBillSanityTests: XCTestCase {
    static let names = ["Marisol", "Héctor", "Keishla", "Yadiel", "Ana", "Luis", "Carmen", "Joel"]

    /// 40 lines, every fourth one of 2 to 4 units, each unit shared by one to three people, tax, service and a tip.
    static func bigBill() -> BillSession {
        let people = names.enumerated().map { Participant(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0.offset + 1))!, name: $0.element, orderIndex: $0.offset) }
        var items: [DraftItem] = []
        for number in 1 ... 40 {
            let quantity = number % 4 == 0 ? 2 + number % 3 : 1
            items.append(DraftItem(
                id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", number))!,
                name: "Plato \(number)",
                quantity: quantity,
                lineTotal: DraftAmount(minorUnits: (350 + number * 137) * quantity)
            ))
        }
        let subtotal = items.reduce(0) { $0 + $1.lineTotal.minorUnits }
        let tax = Int((Double(subtotal) * 0.115).rounded())
        var session = BillSession(
            draft: ReceiptDraft(
                items: items,
                subtotal: DraftAmount(minorUnits: subtotal),
                tax: DraftAmount(minorUnits: tax),
                total: DraftAmount(minorUnits: subtotal + tax)
            ),
            merchantName: "Fonda Doña Lola",
            date: Date(timeIntervalSince1970: 1_791_892_800),
            participants: people,
            tip: .percentage(percent: 18, basis: .preTaxSubtotal)
        )
        func number(of item: DraftItem) -> Int { items.firstIndex { $0.id == item.id } ?? 0 }
        for item in items {
            for unit in 0 ..< item.quantity {
                // Deterministic: the same bill in every run.
                let sharers = 1 + (number(of: item) + unit) % 3
                let first = (item.quantity * 7 + unit * 3 + number(of: item)) % people.count
                let who = (0 ..< sharers).map { people[(first + $0) % people.count].id }
                session.assignUnit(itemID: item.id, unitIndex: unit, participantIDs: who)
            }
        }
        return session
    }

    static func elapsed(_ work: () throws -> Void) rethrows -> Duration {
        try ContinuousClock().measure(work)
    }

    func testTheBigBillIsFullyAssignedAndAddsUpToTheCent() {
        let session = Self.bigBill()
        XCTAssertEqual(session.draft.items.count, 40)
        XCTAssertEqual(session.participants.count, 8)
        XCTAssertTrue(session.unassignedUnits.isEmpty)
        XCTAssertTrue(session.canShare, "\(String(describing: session.shareBlockReason))")
        XCTAssertEqual(session.personBreakdowns.map(\.totalOwedCents).reduce(0, +), session.confirmedBillTotalCents)
    }

    func testPricingAndTheShareTextForTheBigBillAreInstant() {
        let session = Self.bigBill()
        var text = ""
        let duration = Self.elapsed {
            for _ in 0 ..< 20 {
                _ = session.personBreakdowns
                _ = session.splitResult
                _ = session.unassignedUnits
                _ = session.canShare
                text = ShareSummaryBuilder.build(for: session, language: .es)
            }
        }
        // Twenty full passes, i.e. far more than a screen does between two frames.
        XCTAssertLessThan(duration, .seconds(2), "20 passes took \(duration)")
        for name in Self.names { XCTAssertTrue(text.contains(name), name) }
    }

    func testMarkingEveryUnitOfTheBigBillOneAtATimeStaysFast() {
        var session = Self.bigBill()
        let people = session.participants.map(\.id)
        let duration = Self.elapsed {
            // What painting a whole receipt does: clear, then mark one unit at a time, reading the totals each time.
            session.assignments = []
            for item in session.draft.items {
                for unit in 0 ..< item.quantity {
                    session.assignUnit(itemID: item.id, unitIndex: unit, participantIDs: [people[unit % people.count]])
                    _ = session.preTaxSubtotalCents(for: people[0])
                }
            }
            session.splitRestEvenly()
        }
        XCTAssertLessThan(duration, .seconds(3), "marking all units took \(duration)")
        XCTAssertTrue(session.unassignedUnits.isEmpty)
    }

    func testTheDraftOfTheBigBillIsSmallAndRoundTripsQuickly() throws {
        let session = Self.bigBill()
        let data = try BillSessionCoding.encoder().encode(session)
        XCTAssertLessThan(data.count, 200_000, "the draft file is \(data.count) bytes")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("esplitealo-large-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileBillDraftStore(directory: directory)
        let duration = try Self.elapsed {
            for _ in 0 ..< 100 {
                try store.save(session)
                XCTAssertEqual(try store.load(), session)
            }
        }
        // 100 atomic writes and reads: the app does one per half second of editing at most.
        XCTAssertLessThan(duration, .seconds(10), "100 save and load cycles took \(duration)")
    }

    #if canImport(Darwin)
    private static func residentBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : nil
    }

    func testRepeatedSavesAndPricingOfTheBigBillDoNotGrowTheProcess() throws {
        let session = Self.bigBill()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("esplitealo-large-mem-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileBillDraftStore(directory: directory)

        func cycle() throws {
            try store.save(session)
            _ = try store.load()
            _ = session.personBreakdowns
            _ = ShareSummaryBuilder.build(for: session, language: .en)
        }
        // Warm up allocator pools and caches first, then measure a long run.
        for _ in 0 ..< 50 { try cycle() }
        let before = try XCTUnwrap(Self.residentBytes())
        for _ in 0 ..< 500 { try cycle() }
        let after = try XCTUnwrap(Self.residentBytes())

        let growth = Int64(after) - Int64(before)
        XCTAssertLessThan(growth, 30 * 1024 * 1024, "resident memory grew by \(growth / 1024) KiB over 500 cycles")
    }
    #endif
}
