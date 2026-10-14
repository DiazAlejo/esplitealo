import XCTest
@testable import EsplitealoCore

final class BillCalculatorTests: XCTestCase {
    private let calculator = BillCalculator()

    // MARK: - Helpers

    private func participant(_ name: String, order: Int) -> Participant {
        Participant(name: name, orderIndex: order)
    }

    private func item(_ description: String, cents: Int, quantity: Int = 1, id: UUID = UUID()) -> ReceiptItem {
        ReceiptItem(id: id, description: description, quantity: quantity, totalPriceCents: cents)
    }

    private func assign(_ item: ReceiptItem, unitIndex: Int = 0, to participants: [Participant]) -> ItemAssignment {
        ItemAssignment(itemID: item.id, unitIndex: unitIndex, participantIDs: participants.map(\.id))
    }

    private func receipt(
        items: [ReceiptItem],
        tax: Int,
        tip: TipConfiguration,
        confirmedTotal: Int,
        participants: [Participant],
        assignments: [ItemAssignment]
    ) -> Receipt {
        Receipt(
            items: items,
            taxCents: tax,
            tip: tip,
            confirmedTotalCents: confirmedTotal,
            participants: participants,
            assignments: assignments
        )
    }

    private func share(_ result: BillSplitResult, participant: Participant) -> ParticipantShare {
        result.shares.first { $0.participantID == participant.id }!
    }

    // MARK: - Golden: captain $100 / $10 / $20

    func testGoldenHundredTenTwenty() {
        let alex = participant("Alex", order: 0)
        let sam = participant("Sam", order: 1)
        let alexItem = item("Alex plate", cents: 6000)
        let samItem = item("Sam plate", cents: 4000)
        let r = receipt(
            items: [alexItem, samItem],
            tax: 1000,
            tip: .percentage(percent: 20, basis: .preTaxSubtotal),
            confirmedTotal: 13000,
            participants: [alex, sam],
            assignments: [
                assign(alexItem, to: [alex]),
                assign(samItem, to: [sam]),
            ]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertTrue(result.isSettled)
        XCTAssertTrue(result.totalsMatch)
        XCTAssertEqual(share(result, participant: alex).itemSubtotalCents, 6000)
        XCTAssertEqual(share(result, participant: alex).taxShareCents, 600)
        XCTAssertEqual(share(result, participant: alex).tipShareCents, 1200)
        XCTAssertEqual(share(result, participant: alex).amountOwedCents, 7800)
        XCTAssertEqual(share(result, participant: sam).amountOwedCents, 5200)
        XCTAssertEqual(result.shares.map(\.amountOwedCents).reduce(0, +), 13000)
    }

    // MARK: - Golden: $3.50 / 3 people

    func testGoldenThreeFiftySplitThreeWays() {
        let a = participant("A", order: 0)
        let b = participant("B", order: 1)
        let c = participant("C", order: 2)
        let line = item("Shared", cents: 350)
        let r = receipt(
            items: [line],
            tax: 0,
            tip: .custom(cents: 0),
            confirmedTotal: 350,
            participants: [a, b, c],
            assignments: [assign(line, to: [a, b, c])]
        )
        let result = calculator.calculate(receipt: r)
        let amounts = [a, b, c].map { share(result, participant: $0).itemSubtotalCents }.sorted()
        XCTAssertEqual(amounts, [116, 117, 117])
        XCTAssertEqual(amounts.reduce(0, +), 350)
        XCTAssertFalse(result.allAdjustments.isEmpty)
    }

    // MARK: - Golden: $12 / 3

    func testGoldenTwelveSplitThree() {
        let people = (0 ..< 3).map { participant("P\($0)", order: $0) }
        let line = item("App", cents: 1200)
        let r = receipt(
            items: [line],
            tax: 0,
            tip: .custom(cents: 0),
            confirmedTotal: 1200,
            participants: people,
            assignments: [assign(line, to: people)]
        )
        let result = calculator.calculate(receipt: r)
        for p in people {
            XCTAssertEqual(share(result, participant: p).itemSubtotalCents, 400)
        }
        XCTAssertTrue(result.allAdjustments.isEmpty)
    }

    // MARK: - Quantity line

    func testQuantityLinePerUnitAssignment() {
        let alex = participant("Alex", order: 0)
        let ben = participant("Ben", order: 1)
        let cy = participant("Cy", order: 2)
        let entree = item("Entree", cents: 2400, quantity: 2)
        let r = receipt(
            items: [entree],
            tax: 0,
            tip: .custom(cents: 0),
            confirmedTotal: 2400,
            participants: [alex, ben, cy],
            assignments: [
                assign(entree, unitIndex: 0, to: [alex]),
                assign(entree, unitIndex: 1, to: [ben, cy]),
            ]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertEqual(share(result, participant: alex).itemSubtotalCents, 1200)
        XCTAssertEqual(share(result, participant: ben).itemSubtotalCents, 600)
        XCTAssertEqual(share(result, participant: cy).itemSubtotalCents, 600)
    }

    // MARK: - Zero-item person

    func testZeroItemPersonGetsNoTaxOrTip() {
        let alex = participant("Alex", order: 0)
        let chris = participant("Chris", order: 1)
        let line = item("Food", cents: 1000)
        let r = receipt(
            items: [line],
            tax: 100,
            tip: .percentage(percent: 10, basis: .preTaxSubtotal),
            confirmedTotal: 1200,
            participants: [alex, chris],
            assignments: [assign(line, to: [alex])]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertEqual(share(result, participant: chris).itemSubtotalCents, 0)
        XCTAssertEqual(share(result, participant: chris).taxShareCents, 0)
        XCTAssertEqual(share(result, participant: chris).tipShareCents, 0)
        XCTAssertTrue(share(result, participant: chris).adjustments.isEmpty)
    }

    // MARK: - Post-tax tip basis

    func testPostTaxTipBasis() {
        let alex = participant("Alex", order: 0)
        let line = item("Meal", cents: 10000)
        let r = receipt(
            items: [line],
            tax: 1000,
            tip: .percentage(percent: 20, basis: .postTaxTotal),
            confirmedTotal: 13200,
            participants: [alex],
            assignments: [assign(line, to: [alex])]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertEqual(result.tipCents, 2200)
        XCTAssertEqual(share(result, participant: alex).amountOwedCents, 13200)
    }

    // MARK: - Custom tip

    func testCustomTipAmount() {
        let a = participant("A", order: 0)
        let b = participant("B", order: 1)
        let i1 = item("A", cents: 6000)
        let i2 = item("B", cents: 4000)
        let r = receipt(
            items: [i1, i2],
            tax: 0,
            tip: .custom(cents: 1500),
            confirmedTotal: 11500,
            participants: [a, b],
            assignments: [assign(i1, to: [a]), assign(i2, to: [b])]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertEqual(result.tipCents, 1500)
        XCTAssertEqual(share(result, participant: a).tipShareCents, 900)
        XCTAssertEqual(share(result, participant: b).tipShareCents, 600)
    }

    // MARK: - One person

    func testOnePersonBill() {
        let solo = participant("Solo", order: 0)
        let line = item("Everything", cents: 5000)
        let r = receipt(
            items: [line],
            tax: 500,
            tip: .percentage(percent: 18, basis: .preTaxSubtotal),
            confirmedTotal: 6400,
            participants: [solo],
            assignments: [assign(line, to: [solo])]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertEqual(result.tipCents, 900)
        XCTAssertEqual(share(result, participant: solo).amountOwedCents, 6400)
    }

    // MARK: - All items shared

    func testAllItemsSharedAmongEveryone() {
        let people = (0 ..< 3).map { participant("P\($0)", order: $0) }
        let line = item("Pitcher", cents: 900)
        let r = receipt(
            items: [line],
            tax: 90,
            tip: .percentage(percent: 10, basis: .preTaxSubtotal),
            confirmedTotal: 1080,
            participants: people,
            assignments: [assign(line, to: people)]
        )
        let result = calculator.calculate(receipt: r)
        for p in people {
            XCTAssertEqual(share(result, participant: p).itemSubtotalCents, 300)
            XCTAssertEqual(share(result, participant: p).taxShareCents, 30)
            XCTAssertEqual(share(result, participant: p).tipShareCents, 30)
        }
        XCTAssertEqual(result.shares.map(\.amountOwedCents).reduce(0, +), 1080)
    }

    // MARK: - Many people tax leftovers

    func testManyPeopleTaxLeftoverCents() {
        let people = (0 ..< 5).map { participant("P\($0)", order: $0) }
        let lines = people.enumerated().map { index, p in
            let line = item("Item\(index)", cents: 2000)
            return (line, assign(line, to: [p]))
        }
        let r = receipt(
            items: lines.map(\.0),
            tax: 103,
            tip: .custom(cents: 0),
            confirmedTotal: 10103,
            participants: people,
            assignments: lines.map(\.1)
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertEqual(result.shares.map(\.taxShareCents).reduce(0, +), 103)
        XCTAssertGreaterThan(result.allAdjustments.filter { $0.pool == .tax }.count, 0)
    }

    // MARK: - Tip percent half-up

    func testTipPercentRoundsHalfUp() {
        let p = participant("P", order: 0)
        let line = item("Meal", cents: 3333)
        let r = receipt(
            items: [line],
            tax: 0,
            tip: .percentage(percent: 15, basis: .preTaxSubtotal),
            confirmedTotal: 3833,
            participants: [p],
            assignments: [assign(line, to: [p])]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertEqual(result.tipCents, 500)
    }

    // MARK: - Unclaimed blocks settled

    func testUnassignedItemNotSettled() {
        let a = participant("A", order: 0)
        let claimed = item("Claimed", cents: 500)
        let loose = item("Loose", cents: 500)
        let r = receipt(
            items: [claimed, loose],
            tax: 0,
            tip: .custom(cents: 0),
            confirmedTotal: 1000,
            participants: [a],
            assignments: [assign(claimed, to: [a])]
        )
        let result = calculator.calculate(receipt: r)
        XCTAssertFalse(result.isSettled)
    }

    func testSplitRestEvenlyClaimsRemainingUnits() {
        let a = participant("A", order: 0)
        let b = participant("B", order: 1)
        let loose = item("Loose", cents: 200)
        let r = receipt(
            items: [loose],
            tax: 0,
            tip: .custom(cents: 0),
            confirmedTotal: 200,
            participants: [a, b],
            assignments: []
        )
        let updated = calculator.splitRestEvenly(receipt: r)
        let result = calculator.calculate(receipt: updated)
        XCTAssertTrue(result.isSettled)
        XCTAssertEqual(share(result, participant: a).itemSubtotalCents, 100)
        XCTAssertEqual(share(result, participant: b).itemSubtotalCents, 100)
    }

    // MARK: - Invariants on golden bills

    func testInvariantsOnRepresentativeReceipt() {
        let alex = participant("Alex", order: 0)
        let sam = participant("Sam", order: 1)
        let alexItem = item("A", cents: 6000)
        let samItem = item("B", cents: 4000)
        let r = receipt(
            items: [alexItem, samItem],
            tax: 1000,
            tip: .percentage(percent: 20, basis: .preTaxSubtotal),
            confirmedTotal: 13000,
            participants: [alex, sam],
            assignments: [assign(alexItem, to: [alex]), assign(samItem, to: [sam])]
        )
        assertInvariants(receipt: r)
    }

    func testDeterminism() {
        let people = (0 ..< 3).map { participant("P\($0)", order: $0) }
        let line = item("X", cents: 350)
        let r = receipt(
            items: [line],
            tax: 0,
            tip: .custom(cents: 0),
            confirmedTotal: 350,
            participants: people,
            assignments: [assign(line, to: people)]
        )
        let first = calculator.calculate(receipt: r)
        let second = calculator.calculate(receipt: r)
        XCTAssertEqual(first, second)
    }

    // MARK: - Property-style loop (fixed seed)

    func testPseudoRandomBillsPreserveInvariants() {
        var rng = SeededRNG(seed: 42)
        for _ in 0 ..< 200 {
            let participantCount = rng.nextInt(in: 1 ... 6)
            let people = (0 ..< participantCount).map { participant("P\($0)", order: $0) }
            let itemCount = rng.nextInt(in: 1 ... 5)
            var items: [ReceiptItem] = []
            var assignments: [ItemAssignment] = []
            for i in 0 ..< itemCount {
                let cents = rng.nextInt(in: 1 ... 5000)
                let qty = rng.nextInt(in: 1 ... 3)
                let line = item("L\(i)", cents: cents, quantity: qty)
                items.append(line)
                for unit in 0 ..< qty {
                    let shareCount = rng.nextInt(in: 1 ... participantCount)
                    let chosen = people.shuffled(using: &rng).prefix(shareCount)
                    assignments.append(assign(line, unitIndex: unit, to: Array(chosen)))
                }
            }
            let subtotal = items.reduce(0) { $0 + $1.totalPriceCents }
            let tax = rng.nextInt(in: 0 ... subtotal / 5)
            let tipPercent = rng.nextInt(in: 0 ... 25)
            let tipCents = (subtotal * tipPercent + 50) / 100
            let total = subtotal + tax + tipCents
            let r = receipt(
                items: items,
                tax: tax,
                tip: .percentage(percent: tipPercent, basis: .preTaxSubtotal),
                confirmedTotal: total,
                participants: people,
                assignments: assignments
            )
            assertInvariants(receipt: r)
        }
    }

    private func assertInvariants(receipt: Receipt) {
        let result = calculator.calculate(receipt: receipt)
        XCTAssertTrue(result.isSettled)
        XCTAssertTrue(result.totalsMatch)

        let taxSum = result.shares.map(\.taxShareCents).reduce(0, +)
        XCTAssertEqual(taxSum, receipt.taxCents)

        if case let .percentage(percent, basis) = receipt.tip {
            let subtotal = receipt.items.reduce(0) { $0 + $1.totalPriceCents }
            let basisAmount = basis == .preTaxSubtotal ? subtotal : subtotal + receipt.taxCents
            let expectedTip = (basisAmount * percent + 50) / 100
            XCTAssertEqual(result.tipCents, expectedTip)
        }

        let tipSum = result.shares.map(\.tipShareCents).reduce(0, +)
        XCTAssertEqual(tipSum, result.tipCents)

        let owedSum = result.shares.map(\.amountOwedCents).reduce(0, +)
        XCTAssertEqual(owedSum, receipt.confirmedTotalCents)

        for item in receipt.items {
            let unitPrices = BillCalculator.unitPrices(lineTotal: item.totalPriceCents, quantity: item.quantity)
            for unitIndex in 0 ..< item.quantity {
                let assignees = BillCalculator.assignees(for: item.id, unitIndex: unitIndex, in: receipt.assignments)
                let participants = receipt.participants.filter { assignees.contains($0.id) }
                let weights = participants.map { _ in 1 }
                let (unitShares, _) = BillCalculator.allocate(
                    amount: unitPrices[unitIndex],
                    recipients: participants,
                    weights: weights,
                    pool: .itemUnit(itemID: item.id, unitIndex: unitIndex)
                )
                XCTAssertEqual(unitShares.reduce(0, +), unitPrices[unitIndex])
            }
        }

        let second = calculator.calculate(receipt: receipt)
        XCTAssertEqual(result.shares.map(\.amountOwedCents), second.shares.map(\.amountOwedCents))
    }
}

// MARK: - Seeded RNG

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = next() % span
        return range.lowerBound + Int(value)
    }
}
