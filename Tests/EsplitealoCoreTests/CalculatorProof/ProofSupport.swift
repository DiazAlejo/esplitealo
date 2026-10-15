import Foundation
import Testing
@testable import EsplitealoCore

/// Records a failed property with the seed that reproduces it.
@discardableResult
func expectProperty(
    _ holds: @autoclosure () -> Bool,
    seed: String,
    _ what: @autoclosure () -> String,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Bool {
    if holds() { return true }
    Issue.record(
        "seed \(seed): \(what())  (replay: ESPLITEALO_PROOF_SEED=\(seed) swift test --filter CalculatorProof)",
        sourceLocation: sourceLocation
    )
    return false
}

/// Arithmetic the tests use to state expectations. Deliberately plain and separate from the engine.
enum ProofMath {
    /// Price of one unit of a quantity line: the first `lineTotal mod quantity` units cost one cent more.
    static func unitPrice(lineTotal: Int, quantity: Int, unit: Int) -> Int {
        lineTotal / quantity + (unit < lineTotal % quantity ? 1 : 0)
    }

    /// `floor(amount * weight / totalWeight)` for each weight; all zero when there is no weight at all.
    static func floorQuotients(amount: Int, weights: [Int]) -> [Int] {
        let total = weights.reduce(0, +)
        guard total > 0 else { return weights.map { _ in 0 } }
        return weights.map { amount * $0 / total }
    }

    /// `(amount * weight) mod totalWeight`: the numerator of each person's fractional part.
    static func remainders(amount: Int, weights: [Int]) -> [Int] {
        let total = weights.reduce(0, +)
        guard total > 0 else { return weights.map { _ in 0 } }
        return weights.map { amount * $0 % total }
    }

    static func ceilDiv(_ numerator: Int, _ denominator: Int) -> Int {
        (numerator + denominator - 1) / denominator
    }
}

/// What a bill claims about itself, worked out directly from the generated numbers (not from the engine).
struct BillFacts {
    let bill: GeneratedBill
    /// `[item][unit]`: the real people on that unit, once, in position order.
    let assignees: [[[Int]]]

    init(_ bill: GeneratedBill) {
        self.bill = bill
        var table = bill.items.map { item in Array(repeating: [Int](), count: item.quantity) }
        for claim in bill.assignments {
            table[claim.item][claim.unit] = Array(Set(claim.participants.filter { $0 < bill.participantCount })).sorted()
        }
        assignees = table
    }

    func price(item: Int, unit: Int) -> Int {
        ProofMath.unitPrice(lineTotal: bill.items[item].lineTotalCents, quantity: bill.items[item].quantity, unit: unit)
    }

    var unclaimedUnits: Int {
        assignees.reduce(0) { $0 + $1.filter(\.isEmpty).count }
    }

    var isSettled: Bool { unclaimedUnits == 0 }

    /// Sum of the prices of units somebody real claimed.
    var claimedTotal: Int {
        var total = 0
        for (item, units) in assignees.enumerated() {
            for (unit, who) in units.enumerated() where !who.isEmpty { total += price(item: item, unit: unit) }
        }
        return total
    }

    /// Units a person shares with at least one other real person.
    func sharedUnits(of position: Int) -> Int {
        assignees.reduce(0) { sum, units in
            sum + units.filter { $0.contains(position) && $0.count > 1 }.count
        }
    }

    /// The tip the rules ask for: custom as entered, or the percentage of the basis rounded half up.
    var tipCents: Int {
        switch bill.sessionTip.configuration {
        case let .custom(cents): cents
        case let .percentage(percent, basis):
            Self.halfUp(
                basis: basis == .postTaxTotal ? bill.itemsSubtotalCents + bill.taxCents : bill.itemsSubtotalCents,
                percent: percent
            )
        }
    }

    /// The unique integer `tip` with `-50 < 100 * tip - basis * percent <= 50` (nearest cent, halves up).
    static func halfUp(basis: Int, percent: Int) -> Int {
        var tip = basis * percent / 100
        while 100 * tip - basis * percent <= -50 { tip += 1 }
        while 100 * tip - basis * percent > 50 { tip -= 1 }
        return tip
    }
}

extension BillSplitResult {
    /// Shares in the bill's participant positions (the engine returns them in participant order).
    func shares(for bill: GeneratedBill) -> [ParticipantShare] {
        let byID = Dictionary(uniqueKeysWithValues: shares.map { ($0.participantID, $0) })
        return (0 ..< bill.participantCount).map { byID[GeneratedBill.participantID($0)]! }
    }
}

extension GeneratedBill {
    /// The same bill with every real claim moved to one person (a unit nobody claimed stays unclaimed).
    func ownedEntirely(by position: Int) -> GeneratedBill {
        var copy = self
        copy.assignments = assignments.compactMap { claim in
            claim.participants.contains(where: { $0 < participantCount })
                ? Claim(item: claim.item, unit: claim.unit, participants: [position])
                : nil
        }
        return copy
    }
}
