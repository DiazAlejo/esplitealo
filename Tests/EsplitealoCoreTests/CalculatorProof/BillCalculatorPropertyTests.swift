import Foundation
import Testing
@testable import EsplitealoCore

extension Receipt {
    func replacing(
        items: [ReceiptItem]? = nil,
        participants: [Participant]? = nil,
        assignments: [ItemAssignment]? = nil
    ) -> Receipt {
        Receipt(
            items: items ?? self.items,
            taxCents: taxCents,
            tip: tip,
            confirmedTotalCents: confirmedTotalCents,
            participants: participants ?? self.participants,
            assignments: assignments ?? self.assignments
        )
    }
}

/// Property tests of `BillCalculator` over seeded, generated bills.
///
/// Each test case is a batch of bills; every bill has its own seed, printed when a property fails.
/// The statement of each property is in its display name and in docs/CALCULATOR_PROOF.md.
@Suite("CalculatorProof: BillCalculator properties")
struct CalculatorProofCalculatorProperties {
    private let calculator = BillCalculator()

    // MARK: - Conservation

    @Test("pools are shared out exactly and every cent is accounted for", arguments: PropertySeeds.batches)
    func poolsConserve(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let facts = BillFacts(bill)
            let result = calculator.calculate(receipt: bill.receipt())
            let shares = result.shares(for: bill)
            let subtotals = shares.map(\.itemSubtotalCents)
            let weighted = subtotals.reduce(0, +) > 0
            let id = bill.seed

            expectProperty(subtotals.reduce(0, +) == facts.claimedTotal, seed: id, "item subtotals do not add up to the claimed units")
            expectProperty(
                shares.map(\.taxShareCents).reduce(0, +) == (weighted ? bill.taxCents : 0),
                seed: id, "tax shares do not add up to the tax"
            )
            expectProperty(
                shares.map(\.tipShareCents).reduce(0, +) == (weighted ? result.tipCents : 0),
                seed: id, "tip shares do not add up to the tip"
            )
            expectProperty(result.tipCents == facts.tipCents, seed: id, "tip \(result.tipCents) != rule \(facts.tipCents)")
            for share in shares {
                expectProperty(
                    share.amountOwedCents == share.itemSubtotalCents + share.taxShareCents + share.tipShareCents,
                    seed: id, "owed is not items + tax + tip"
                )
            }
            if facts.isSettled, weighted {
                expectProperty(
                    shares.map(\.amountOwedCents).reduce(0, +) == bill.itemsSubtotalCents + bill.taxCents + result.tipCents,
                    seed: id, "settled bill: people do not owe exactly the bill total"
                )
                expectProperty(
                    shares.map(\.amountOwedCents).reduce(0, +) == result.calculatedTotalCents,
                    seed: id, "settled bill: people do not owe calculatedTotalCents"
                )
            }
        }
    }

    @Test("every leftover cent is a surfaced adjustment, and each share is its floor plus that cent", arguments: PropertySeeds.batches)
    func leftoverCentsAreSurfaced(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let facts = BillFacts(bill)
            let result = calculator.calculate(receipt: bill.receipt())
            let shares = result.shares(for: bill)
            let id = bill.seed
            let ids = (0 ..< bill.participantCount).map(GeneratedBill.participantID)
            let order = bill.participants.map(\.orderIndex)

            // Tax and tip: weights are the item subtotals.
            let weights = shares.map(\.itemSubtotalCents)
            for (name, amount, got, pool) in [
                ("tax", bill.taxCents, shares.map(\.taxShareCents), RoundingAdjustment.Pool.tax),
                ("tip", result.tipCents, shares.map(\.tipShareCents), RoundingAdjustment.Pool.tip),
            ] {
                let floors = ProofMath.floorQuotients(amount: amount, weights: weights)
                let adjusted = result.allAdjustments.filter { $0.pool == pool }
                let expectedLeftover = weights.reduce(0, +) > 0 ? amount - floors.reduce(0, +) : 0
                expectProperty(adjusted.count == expectedLeftover, seed: id, "\(name): \(adjusted.count) adjustments for \(expectedLeftover) leftover cents")
                expectProperty(Set(adjusted.map(\.participantID)).count == adjusted.count, seed: id, "\(name): someone adjusted twice")
                expectProperty(adjusted.allSatisfy { $0.cents == 1 }, seed: id, "\(name): an adjustment is not one cent")
                for position in 0 ..< bill.participantCount {
                    let got1 = adjusted.contains { $0.participantID == ids[position] } ? 1 : 0
                    expectProperty(got[position] == floors[position] + got1, seed: id, "\(name): share of \(position) is not floor + adjustment")
                    expectProperty(got1 == 0 || weights[position] > 0, seed: id, "\(name): a person with no items received a leftover cent")
                }
            }

            // Item units: equal weights, so the leftover cents go to the earliest assignees.
            var unitAdjustmentCount = 0
            for (item, units) in facts.assignees.enumerated() {
                for (unit, who) in units.enumerated() {
                    let pool = RoundingAdjustment.Pool.itemUnit(itemID: GeneratedBill.itemID(item), unitIndex: unit)
                    let adjusted = result.allAdjustments.filter { $0.pool == pool }
                    unitAdjustmentCount += adjusted.count
                    guard !who.isEmpty else {
                        expectProperty(adjusted.isEmpty, seed: id, "unclaimed unit \(item).\(unit) has adjustments")
                        continue
                    }
                    let leftover = facts.price(item: item, unit: unit) % who.count
                    let earliest = who.sorted { order[$0] < order[$1] }.prefix(leftover).map { ids[$0] }
                    expectProperty(
                        Set(adjusted.map(\.participantID)) == Set(earliest) && adjusted.count == leftover,
                        seed: id, "unit \(item).\(unit): leftover \(leftover) cents did not go to the earliest assignees"
                    )
                }
            }
            let taxTipCount = result.allAdjustments.filter { $0.pool == .tax || $0.pool == .tip }.count
            expectProperty(result.allAdjustments.count == unitAdjustmentCount + taxTipCount, seed: id, "adjustment in an unknown pool")
            expectProperty(
                result.shares.reduce(0) { $0 + $1.adjustments.count } == result.allAdjustments.count,
                seed: id, "person adjustments and allAdjustments disagree"
            )
        }
    }

    // MARK: - Signs and zero-item people

    @Test("no amount is ever negative", arguments: PropertySeeds.batches)
    func noNegativeAmounts(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let result = calculator.calculate(receipt: bill.receipt())
            for share in result.shares {
                expectProperty(
                    min(share.itemSubtotalCents, share.taxShareCents, share.tipShareCents, share.amountOwedCents) >= 0,
                    seed: bill.seed, "a share is negative"
                )
            }
            expectProperty(result.tipCents >= 0, seed: bill.seed, "negative tip")
        }
    }

    @Test("a person with no items owes no tax, no tip and gets no leftover cent", arguments: PropertySeeds.batches)
    func personWithoutItemsOwesNothing(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let result = calculator.calculate(receipt: bill.receipt())
            for share in result.shares where share.itemSubtotalCents == 0 {
                expectProperty(
                    share.taxShareCents == 0 && share.tipShareCents == 0 && share.amountOwedCents == 0,
                    seed: bill.seed, "person with no items owes \(share.amountOwedCents)"
                )
                expectProperty(
                    !share.adjustments.contains { $0.pool == .tax || $0.pool == .tip },
                    seed: bill.seed, "person with no items received a tax/tip leftover cent"
                )
            }
        }
    }

    // MARK: - Participant order

    @Test("array order is irrelevant: only orderIndex decides who gets a leftover cent", arguments: PropertySeeds.batches)
    func arrayOrderDoesNotMatter(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            var rng = SplitMix64(seed: seed ^ 0xA55A)
            let receipt = bill.receipt()
            let shuffled = receipt.replacing(
                participants: rng.shuffled(receipt.participants),
                assignments: rng.shuffled(receipt.assignments)
            )
            expectProperty(
                calculator.calculate(receipt: receipt).shares.sorted { $0.participantID.uuidString < $1.participantID.uuidString }
                    == calculator.calculate(receipt: shuffled).shares.sorted { $0.participantID.uuidString < $1.participantID.uuidString },
                seed: bill.seed, "shuffling the participant array changed the split"
            )
        }
    }

    @Test("reordering people moves only leftover cents, within a computed bound", arguments: PropertySeeds.batches)
    func reorderingMovesOnlyLeftoverCents(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let facts = BillFacts(bill)
            var rng = SplitMix64(seed: seed ^ 0x0DE5)
            let newOrders = rng.shuffled(bill.participants.map(\.orderIndex))
            let reordered = bill.receipt().replacing(
                participants: bill.participantModels().enumerated().map {
                    Participant(id: $1.id, name: $1.name, orderIndex: newOrders[$0])
                }
            )
            let before = calculator.calculate(receipt: bill.receipt())
            let after = calculator.calculate(receipt: reordered)
            let (a, b) = (before.shares(for: bill), after.shares(for: bill))
            let weight = facts.claimedTotal
            let id = bill.seed

            expectProperty(a.map(\.amountOwedCents).reduce(0, +) == b.map(\.amountOwedCents).reduce(0, +), seed: id, "reordering changed what everyone owes together")
            expectProperty(before.tipCents == after.tipCents && before.isSettled == after.isSettled, seed: id, "reordering changed the tip or settlement")
            if before.allAdjustments.isEmpty {
                expectProperty(a == b, seed: id, "no leftover cents anywhere, yet reordering changed a share")
            }
            guard weight > 0 else { continue }
            for position in 0 ..< bill.participantCount {
                let shared = facts.sharedUnits(of: position)
                let itemDelta = abs(a[position].itemSubtotalCents - b[position].itemSubtotalCents)
                expectProperty(itemDelta <= shared, seed: id, "item subtotal of \(position) moved \(itemDelta) cents with \(shared) shared units")
                if shared == 0 {
                    expectProperty(a[position].itemSubtotalCents == b[position].itemSubtotalCents, seed: id, "unshared person's items changed")
                }
                let bound = shared
                    + ProofMath.ceilDiv(bill.taxCents * shared, weight) + 1
                    + ProofMath.ceilDiv(before.tipCents * shared, weight) + 1
                let delta = abs(a[position].amountOwedCents - b[position].amountOwedCents)
                expectProperty(delta <= bound, seed: id, "person \(position) moved \(delta) cents, bound \(bound)")
            }
        }
    }

    @Test("among people with equal weight the earlier participant never gets less (tax and tip)", arguments: PropertySeeds.batches)
    func earlierParticipantWinsTies(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let result = calculator.calculate(receipt: bill.receipt())
            let shares = result.shares(for: bill)
            let order = bill.participants.map(\.orderIndex)
            for i in shares.indices {
                for j in shares.indices where i != j && order[i] < order[j] {
                    guard shares[i].itemSubtotalCents == shares[j].itemSubtotalCents else { continue }
                    expectProperty(
                        shares[i].taxShareCents >= shares[j].taxShareCents && shares[i].taxShareCents - shares[j].taxShareCents <= 1,
                        seed: bill.seed, "tax: later participant \(j) beat earlier \(i) on equal weight"
                    )
                    expectProperty(
                        shares[i].tipShareCents >= shares[j].tipShareCents && shares[i].tipShareCents - shares[j].tipShareCents <= 1,
                        seed: bill.seed, "tip: later participant \(j) beat earlier \(i) on equal weight"
                    )
                }
            }
        }
    }

    @Test("largest remainder: nobody gets a leftover cent over someone with a larger remainder", arguments: PropertySeeds.batches)
    func leftoverCentsGoToLargestRemainders(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let result = calculator.calculate(receipt: bill.receipt())
            let shares = result.shares(for: bill)
            let weights = shares.map(\.itemSubtotalCents)
            let order = bill.participants.map(\.orderIndex)
            for (amount, got) in [(bill.taxCents, shares.map(\.taxShareCents)), (result.tipCents, shares.map(\.tipShareCents))] {
                let floors = ProofMath.floorQuotients(amount: amount, weights: weights)
                let remainders = ProofMath.remainders(amount: amount, weights: weights)
                for i in weights.indices where weights[i] > 0 && got[i] == floors[i] + 1 {
                    for j in weights.indices where weights[j] > 0 && got[j] == floors[j] {
                        let wins = remainders[i] > remainders[j] || (remainders[i] == remainders[j] && order[i] < order[j])
                        expectProperty(wins, seed: bill.seed, "person \(j) (remainder \(remainders[j])) lost a cent to \(i) (remainder \(remainders[i]))")
                    }
                }
            }
        }
    }

    // MARK: - Consistency

    @Test("one person owning everything owes exactly the bill, with no tax or tip rounding", arguments: PropertySeeds.batches)
    func singleOwnerPaysTheWholeBill(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed, claims: .full)
            var rng = SplitMix64(seed: seed ^ 0x50_1E)
            let owner = rng.below(bill.participantCount)
            let owned = bill.ownedEntirely(by: owner)
            let result = calculator.calculate(receipt: owned.receipt())
            let shares = result.shares(for: owned)
            let total = owned.itemsSubtotalCents + owned.taxCents + result.tipCents
            expectProperty(result.isSettled, seed: bill.seed, "fully claimed bill is not settled")
            if owned.itemsSubtotalCents > 0 {
                expectProperty(shares[owner].amountOwedCents == total, seed: bill.seed, "owner owes \(shares[owner].amountOwedCents), bill is \(total)")
                expectProperty(
                    shares[owner].itemSubtotalCents == owned.itemsSubtotalCents && shares[owner].taxShareCents == owned.taxCents
                        && shares[owner].tipShareCents == result.tipCents,
                    seed: bill.seed, "owner's lines differ from the bill's"
                )
            }
            expectProperty(result.allAdjustments.isEmpty, seed: bill.seed, "sole owner produced rounding adjustments")
            for (position, share) in shares.enumerated() where position != owner {
                expectProperty(share.amountOwedCents == 0, seed: bill.seed, "non-owner \(position) owes \(share.amountOwedCents)")
            }
        }
    }

    @Test("a quantity line equals separate single lines at the documented unit prices", arguments: PropertySeeds.batches)
    func quantityLinesEqualSeparateLines(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let receipt = bill.receipt()
            var expandedItems: [ReceiptItem] = []
            var expandedAssignments: [ItemAssignment] = []
            for (position, item) in bill.items.enumerated() {
                for unit in 0 ..< item.quantity {
                    let expandedID = UUID(uuidString: String(format: "20000000-0000-0000-%04X-%012X", position, unit))!
                    expandedItems.append(ReceiptItem(
                        id: expandedID, description: "unit", quantity: 1,
                        totalPriceCents: ProofMath.unitPrice(lineTotal: item.lineTotalCents, quantity: item.quantity, unit: unit)
                    ))
                    if let assignment = receipt.assignments.first(where: { $0.itemID == GeneratedBill.itemID(position) && $0.unitIndex == unit }) {
                        expandedAssignments.append(ItemAssignment(itemID: expandedID, unitIndex: 0, participantIDs: assignment.participantIDs))
                    }
                }
            }
            let expanded = receipt.replacing(items: expandedItems, assignments: expandedAssignments)
            let one = calculator.calculate(receipt: receipt)
            let other = calculator.calculate(receipt: expanded)
            func amounts(_ r: BillSplitResult) -> [[Int]] {
                r.shares(for: bill).map { [$0.itemSubtotalCents, $0.taxShareCents, $0.tipShareCents, $0.amountOwedCents, $0.adjustments.count] }
            }
            expectProperty(amounts(one) == amounts(other), seed: bill.seed, "quantity line and expanded lines split differently")
            expectProperty(one.isSettled == other.isSettled && one.tipCents == other.tipCents, seed: bill.seed, "settlement or tip differs")
        }
    }

    // MARK: - Tip

    @Test("tip follows the half-up rule on the documented basis, and custom tip is verbatim", arguments: PropertySeeds.batches)
    func tipRoundsHalfUp(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            var rng = SplitMix64(seed: seed)
            let range = rng.weighted([((0, 99), 2), ((100, 99999), 6), ((100_000, 9_999_999), 2)])
            let basisAmount = rng.between(range.0, range.1)
            let tax = rng.between(0, basisAmount / 5)
            let percent = rng.between(0, 100)
            // A basis whose percentage lands exactly on half a cent (when one exists) is the case that matters most.
            var halfCent = basisAmount
            for candidate in basisAmount ..< basisAmount + 200 where candidate * percent % 100 == 50 {
                halfCent = candidate
                break
            }
            let id = String(seed)
            for basis in [basisAmount, halfCent] {
                let pre = BillCalculator.tipAmount(tip: .percentage(percent: percent, basis: .preTaxSubtotal), itemsSubtotal: basis, taxCents: tax)
                let post = BillCalculator.tipAmount(tip: .percentage(percent: percent, basis: .postTaxTotal), itemsSubtotal: basis, taxCents: tax)
                expectProperty(-50 < 100 * pre - basis * percent && 100 * pre - basis * percent <= 50, seed: id, "pre-tax tip \(pre) is not the half-up rounding of \(percent)% of \(basis)")
                expectProperty(-50 < 100 * post - (basis + tax) * percent && 100 * post - (basis + tax) * percent <= 50, seed: id, "post-tax tip \(post) is not the half-up rounding of \(percent)% of \(basis + tax)")
                expectProperty(post >= pre, seed: id, "post-tax tip below pre-tax tip")
                expectProperty(pre == BillFacts.halfUp(basis: basis, percent: percent), seed: id, "tip differs from the half-up reference")
                let higher = BillCalculator.tipAmount(tip: .percentage(percent: percent + 1, basis: .preTaxSubtotal), itemsSubtotal: basis, taxCents: tax)
                expectProperty(higher >= pre, seed: id, "tip decreased when the percentage increased")
                let custom = rng.between(0, 50000)
                expectProperty(
                    BillCalculator.tipAmount(tip: .custom(cents: custom), itemsSubtotal: basis, taxCents: tax) == custom,
                    seed: id, "custom tip was altered"
                )
            }
            if percent * basisAmount % 100 == 50 {
                expectProperty(
                    BillCalculator.tipAmount(tip: .percentage(percent: percent, basis: .preTaxSubtotal), itemsSubtotal: basisAmount, taxCents: 0) == basisAmount * percent / 100 + 1,
                    seed: id, "an exact half cent did not round up"
                )
            }
        }
    }

    // MARK: - Settlement

    @Test("a bill is settled exactly when every unit has a real assignee", arguments: PropertySeeds.batches)
    func unclaimedUnitsBlockSettlement(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let facts = BillFacts(bill)
            let result = calculator.calculate(receipt: bill.receipt())
            expectProperty(result.isSettled == facts.isSettled, seed: bill.seed, "isSettled \(result.isSettled) but \(facts.unclaimedUnits) units are unclaimed")
            if !facts.isSettled {
                let claimedShare = result.shares.map(\.itemSubtotalCents).reduce(0, +)
                expectProperty(claimedShare == facts.claimedTotal, seed: bill.seed, "unclaimed units leaked into somebody's items")
                expectProperty(claimedShare <= bill.itemsSubtotalCents, seed: bill.seed, "claimed total exceeds the bill")
            }
        }
    }

    @Test("splitRestEvenly claims every unclaimed unit and changes nothing that was claimed", arguments: PropertySeeds.batches)
    func splitRestEvenlyOnlyFillsGaps(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let facts = BillFacts(bill)
            let receipt = bill.receipt()
            let filled = calculator.splitRestEvenly(receipt: receipt)
            let result = calculator.calculate(receipt: filled)
            expectProperty(result.isSettled, seed: bill.seed, "bill still unsettled after splitRestEvenly")
            expectProperty(calculator.splitRestEvenly(receipt: filled) == filled, seed: bill.seed, "splitRestEvenly is not idempotent")
            let everyone = Set(bill.participantModels().map(\.id))
            for (item, units) in facts.assignees.enumerated() {
                for (unit, who) in units.enumerated() {
                    let after = filled.assignments.filter { $0.itemID == GeneratedBill.itemID(item) && $0.unitIndex == unit }
                    expectProperty(after.count == 1, seed: bill.seed, "unit \(item).\(unit) has \(after.count) assignment rows")
                    let got = Set(after.first?.participantIDs ?? []).intersection(everyone)
                    if who.isEmpty {
                        expectProperty(got == everyone, seed: bill.seed, "unclaimed unit \(item).\(unit) was not given to everyone")
                    } else {
                        expectProperty(got == Set(who.map(GeneratedBill.participantID)), seed: bill.seed, "claimed unit \(item).\(unit) changed")
                    }
                }
            }
        }
    }

    // MARK: - Reproducibility

    @Test("the same seed always gives the same bill and the same split", arguments: PropertySeeds.batches)
    func reproducibleFromSeed(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let first = GeneratedBill.random(seed: seed)
            let second = GeneratedBill.random(seed: seed)
            expectProperty(first == second, seed: first.seed, "generator is not deterministic")
            expectProperty(
                calculator.calculate(receipt: first.receipt()) == calculator.calculate(receipt: second.receipt()),
                seed: first.seed, "calculation is not deterministic"
            )
            expectProperty(
                BillCalculator().calculate(receipt: first.receipt()) == calculator.calculate(receipt: first.receipt()),
                seed: first.seed, "two calculators disagree"
            )
        }
    }
}

/// The allocation rule on its own (largest remainder), without any bill around it.
@Suite("CalculatorProof: largest-remainder allocation")
struct CalculatorProofAllocationProperties {
    private func people(_ orders: [Int]) -> [Participant] {
        orders.enumerated().map { Participant(id: GeneratedBill.participantID($0), name: "P\($0)", orderIndex: $1) }
    }

    private func draw(_ seed: UInt64) -> (amount: Int, weights: [Int], orders: [Int]) {
        var rng = SplitMix64(seed: seed)
        let count = rng.between(1, 9)
        let range = rng.weighted([((0, 0), 4), ((1, 9), 10), ((10, 999), 30), ((1000, 99999), 40), ((100_000, 9_999_999), 16)])
        let weightRange = rng.weighted([((0, 0), 20), ((1, 3), 25), ((1, 5000), 45), ((1, 900_000), 10)])
        var weights = (0 ..< count).map { _ in rng.between(weightRange.0, weightRange.1) }
        if rng.chance(25) { weights = Array(repeating: weights[0], count: count) }
        let orders = rng.chance(35) ? rng.shuffled(Array(0 ..< count)) : Array(0 ..< count)
        return (rng.between(range.0, range.1), weights, orders)
    }

    @Test("shares add up to the amount; each is its floor or floor + 1; weightless people get nothing", arguments: PropertySeeds.batches)
    func exactAndBounded(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let (amount, weights, orders) = draw(seed)
            let (shares, adjustments) = BillCalculator.allocate(amount: amount, recipients: people(orders), weights: weights, pool: .tax)
            let id = String(seed)
            let floors = ProofMath.floorQuotients(amount: amount, weights: weights)
            if weights.reduce(0, +) == 0 {
                expectProperty(shares.allSatisfy { $0 == 0 } && adjustments.isEmpty, seed: id, "no weight must allocate nothing")
                continue
            }
            expectProperty(shares.reduce(0, +) == amount, seed: id, "shares add up to \(shares.reduce(0, +)), not \(amount)")
            expectProperty(adjustments.count == amount - floors.reduce(0, +), seed: id, "adjustments != leftover cents")
            for i in weights.indices {
                expectProperty(shares[i] == floors[i] || shares[i] == floors[i] + 1, seed: id, "share \(i) outside floor..floor+1")
                if weights[i] == 0 { expectProperty(shares[i] == 0, seed: id, "weightless person \(i) got \(shares[i])") }
            }
        }
    }

    @Test("the result follows the people, not their position in the list", arguments: PropertySeeds.batches)
    func positionIndependent(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let (amount, weights, orders) = draw(seed)
            var rng = SplitMix64(seed: seed ^ 0xBEEF)
            let permutation = rng.shuffled(Array(weights.indices))
            let base = BillCalculator.allocate(amount: amount, recipients: people(orders), weights: weights, pool: .tax).shares
            let permuted = BillCalculator.allocate(
                amount: amount,
                recipients: permutation.map { people(orders)[$0] },
                weights: permutation.map { weights[$0] },
                pool: .tax
            ).shares
            expectProperty(permutation.enumerated().allSatisfy { permuted[$0] == base[$1] }, seed: String(seed), "shares moved with list position")
        }
    }
}
