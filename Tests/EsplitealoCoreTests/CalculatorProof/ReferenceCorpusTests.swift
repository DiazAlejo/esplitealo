import Foundation
import Testing
@testable import EsplitealoCore

/// The reference calculator's corpus (`Tools/reference-calculator`): bills plus the results an
/// independent Python implementation of docs/CALCULATION_RULES.md computed for them.
struct ReferenceCorpus: Decodable {
    struct Generator: Decodable {
        var seed: Int
        var count: Int
    }

    struct PersonExpectation: Decodable {
        var itemSubtotalCents: Int
        var taxShareCents: Int
        var serviceShareCents: Int
        var receiptTipShareCents: Int
        var tipShareCents: Int
        var totalOwedCents: Int
        var itemUnitAdjustments: [[Int]]
        var taxAdjustments: Int
        var tipAdjustments: Int
        var serviceAdjustments: Int
        var printedTipAdjustments: Int
    }

    struct Expectation: Decodable {
        var itemsSubtotalCents: Int
        var taxCents: Int
        var sessionTipCents: Int
        var receiptTipOnBillCents: Int
        var derivedTotalCents: Int
        var isSettled: Bool
        var unassignedUnits: Int
        var reconciles: Bool
        var canShare: Bool
        var nobodyCarriesCharges: Bool
        var people: [PersonExpectation]
    }

    struct Entry: Decodable {
        var id: String
        var bill: GeneratedBill
        var expected: Expectation

        private enum CodingKeys: String, CodingKey { case id, expected }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            expected = try container.decode(Expectation.self, forKey: .expected)
            bill = try GeneratedBill(from: decoder) // the bill's own fields sit beside `id` and `expected`
        }
    }

    struct Allocation: Decodable {
        var amountCents: Int
        var weights: [Int]
        var orderIndices: [Int]
        var shares: [Int]
        var adjusted: [Int]
    }

    var format: Int
    var generator: Generator
    var bills: [Entry]
    var allocations: [Allocation]

    static func load(from url: URL) throws -> ReferenceCorpus {
        try JSONDecoder().decode(ReferenceCorpus.self, from: Data(contentsOf: url))
    }

    static let committedFixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/CalculatorProof/reference-corpus-300.json")
}

/// Compares the Swift engine with the reference results, field by field, person by person.
enum ReferenceComparison {
    /// Every difference between the engine and the reference for one bill; empty means an exact match.
    static func mismatches(_ entry: ReferenceCorpus.Entry) -> [String] {
        let bill = entry.bill
        let expected = entry.expected
        let session = bill.session()
        let split = session.splitResult
        let breakdowns = session.personBreakdowns
        var differences: [String] = []

        func compare<T: Equatable>(_ name: String, _ got: T, _ want: T) {
            if got != want { differences.append("\(name): Swift \(got), reference \(want)") }
        }

        compare("itemsSubtotalCents", bill.itemsSubtotalCents, expected.itemsSubtotalCents)
        compare("taxCents", session.draft.tax?.minorUnits ?? 0, expected.taxCents)
        compare("sessionTipCents", session.sessionTipCents, expected.sessionTipCents)
        compare("calculator tipCents", split.tipCents, expected.sessionTipCents)
        compare("receiptTipOnBillCents", session.receiptTipOnBillCents, expected.receiptTipOnBillCents)
        compare("derivedBillTotalCents", session.derivedBillTotalCents, expected.derivedTotalCents)
        compare("confirmedBillTotalCents", session.confirmedBillTotalCents, expected.derivedTotalCents)
        compare("isSettled", split.isSettled, expected.isSettled)
        compare("unassignedUnits", session.unassignedUnits.count, expected.unassignedUnits)
        compare("reconciles", session.draft.reconciliation.reconciles, expected.reconciles)
        compare("canShare", session.canShare, expected.canShare)
        compare("nobodyCarriesCharges", session.shareBlockReason == .noItemsToCarryCharges, expected.nobodyCarriesCharges)
        compare("people", breakdowns.count, expected.people.count)
        guard breakdowns.count == expected.people.count, bill.participantCount == expected.people.count else { return differences }

        var itemPosition: [UUID: Int] = [:]
        for position in bill.items.indices { itemPosition[GeneratedBill.itemID(position)] = position }

        for position in 0 ..< bill.participantCount {
            let want = expected.people[position]
            let id = GeneratedBill.participantID(position)
            guard let got = breakdowns.first(where: { $0.participantID == id }),
                  let share = split.shares.first(where: { $0.participantID == id })
            else {
                differences.append("person \(position): missing from the result")
                continue
            }
            let tag = "person \(position)"
            compare("\(tag) itemSubtotalCents", got.itemSubtotalCents, want.itemSubtotalCents)
            compare("\(tag) taxShareCents", got.taxShareCents, want.taxShareCents)
            compare("\(tag) serviceShareCents", got.serviceShareCents, want.serviceShareCents)
            compare("\(tag) receiptTipShareCents", got.receiptTipShareCents, want.receiptTipShareCents)
            compare("\(tag) tipShareCents", got.tipShareCents, want.tipShareCents)
            compare("\(tag) totalOwedCents", got.totalOwedCents, want.totalOwedCents)
            compare("\(tag) calculator amountOwedCents", share.amountOwedCents, got.itemSubtotalCents + got.taxShareCents + got.tipShareCents)

            var unitAdjustments: [[Int]] = []
            for adjustment in share.adjustments {
                if case let .itemUnit(itemID, unitIndex) = adjustment.pool, let item = itemPosition[itemID] {
                    unitAdjustments.append([item, unitIndex])
                }
            }
            compare("\(tag) itemUnitAdjustments", unitAdjustments.sorted { $0.lexicographicallyPrecedes($1) }, want.itemUnitAdjustments)
            compare("\(tag) taxAdjustments", share.adjustments.filter { $0.pool == .tax }.count, want.taxAdjustments)
            compare("\(tag) tipAdjustments", share.adjustments.filter { $0.pool == .tip }.count, want.tipAdjustments)
            compare("\(tag) serviceAdjustments", got.adjustments.filter { $0.pool == .serviceCharge }.count, want.serviceAdjustments)
            compare("\(tag) printedTipAdjustments", got.adjustments.filter { $0.pool == .printedTip }.count, want.printedTipAdjustments)
        }
        return differences
    }

    static func mismatches(_ allocation: ReferenceCorpus.Allocation) -> [String] {
        let people = allocation.orderIndices.enumerated().map {
            Participant(id: GeneratedBill.participantID($0), name: "P\($0)", orderIndex: $1)
        }
        let (shares, adjustments) = BillCalculator.allocate(
            amount: allocation.amountCents, recipients: people, weights: allocation.weights, pool: .tax
        )
        var differences: [String] = []
        if shares != allocation.shares { differences.append("shares: Swift \(shares), reference \(allocation.shares)") }
        let adjusted = people.indices.filter { index in adjustments.contains { $0.participantID == people[index].id } }
        if adjusted != allocation.adjusted { differences.append("adjusted: Swift \(adjusted), reference \(allocation.adjusted)") }
        return differences
    }

    /// Runs the whole corpus; returns the number compared and a readable report of the first failures.
    static func run(_ corpus: ReferenceCorpus) -> (compared: Int, report: [String]) {
        var report: [String] = []
        for entry in corpus.bills {
            let differences = mismatches(entry)
            if !differences.isEmpty { report.append("\(entry.id) (seed \(entry.bill.seed)): " + differences.prefix(4).joined(separator: "; ")) }
        }
        for (index, allocation) in corpus.allocations.enumerated() {
            let differences = mismatches(allocation)
            if !differences.isEmpty { report.append("allocation \(index): " + differences.joined(separator: "; ")) }
        }
        return (corpus.bills.count + corpus.allocations.count, report)
    }
}

@Suite("CalculatorProof: reference calculator")
struct CalculatorProofReferenceTests {
    @Test("the committed corpus of about 300 bills matches the independent reference exactly")
    func committedCorpusMatchesReference() throws {
        let corpus = try ReferenceCorpus.load(from: ReferenceCorpus.committedFixtureURL)
        #expect(corpus.format == 1)
        #expect(corpus.bills.count >= 300, "the committed fixture should hold at least 300 bills")
        #expect(corpus.allocations.count >= 300, "the committed fixture should hold at least 300 allocation cases")
        let (compared, report) = ReferenceComparison.run(corpus)
        #expect(report.isEmpty, "\(report.count) of \(compared) cases differ from the reference. First: \(report.prefix(3).joined(separator: " | "))")
    }

    /// Set `ESPLITEALO_REFERENCE_CORPUS` to a corpus written by `generate_corpus.py` (see Scripts/prove-calculator.sh).
    @Test(
        "an externally generated corpus (thousands of bills) matches the reference exactly",
        .enabled(if: ProcessInfo.processInfo.environment["ESPLITEALO_REFERENCE_CORPUS"] != nil)
    )
    func largeCorpusMatchesReference() throws {
        let path = try #require(ProcessInfo.processInfo.environment["ESPLITEALO_REFERENCE_CORPUS"])
        let corpus = try ReferenceCorpus.load(from: URL(fileURLWithPath: path))
        let (compared, report) = ReferenceComparison.run(corpus)
        print("CalculatorProof: compared \(corpus.bills.count) bills and \(corpus.allocations.count) allocation cases from \(path); \(report.count) differences")
        #expect(report.isEmpty, "\(report.count) of \(compared) cases differ from the reference. First: \(report.prefix(5).joined(separator: " | "))")
    }
}
