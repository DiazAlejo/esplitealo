import Foundation
import Testing
@testable import EsplitealoCore

/// A property that passes over bills that never exercise the interesting case proves nothing.
/// These tests fail if the generators stop producing the situations the properties are about.
@Suite("CalculatorProof: generator coverage")
struct CalculatorProofGeneratorCoverage {
    private struct Tally {
        var bills = 0
        var unitLeftover = 0
        var taxLeftover = 0
        var tipLeftover = 0
        var sharedUnits = 0
        var quantityLines = 0
        var unclaimed = 0
        var settled = 0
        var zeroItemPerson = 0
        var multipleTaxLines = 0
        var serviceCharge = 0
        var printedTip = 0
        var customTip = 0
        var postTaxTip = 0
        var gappedOrShuffledOrder = 0
        var strangersOrDuplicates = 0
        var canShare = 0
        var blockedByTotals = 0
        var halfCentTip = 0

        mutating func add(_ bill: GeneratedBill) {
            let facts = BillFacts(bill)
            let session = bill.session()
            let result = BillCalculator().calculate(receipt: bill.receipt())
            bills += 1
            if result.allAdjustments.contains(where: { if case .itemUnit = $0.pool { true } else { false } }) { unitLeftover += 1 }
            if result.allAdjustments.contains(where: { $0.pool == .tax }) { taxLeftover += 1 }
            if result.allAdjustments.contains(where: { $0.pool == .tip }) { tipLeftover += 1 }
            if facts.assignees.joined().contains(where: { $0.count > 1 }) { sharedUnits += 1 }
            if bill.items.contains(where: { $0.quantity > 1 }) { quantityLines += 1 }
            if facts.isSettled { settled += 1 } else { unclaimed += 1 }
            if result.shares.contains(where: { $0.itemSubtotalCents == 0 }) { zeroItemPerson += 1 }
            if bill.taxLinesCents.count > 1 { multipleTaxLines += 1 }
            if bill.serviceChargeCents > 0 { serviceCharge += 1 }
            if bill.printedTipCents != nil { printedTip += 1 }
            if case .custom = bill.sessionTip.configuration { customTip += 1 }
            if case .percentage(_, .postTaxTotal) = bill.sessionTip.configuration { postTaxTip += 1 }
            let orders = bill.participants.map(\.orderIndex)
            if orders != Array(0 ..< orders.count) { gappedOrShuffledOrder += 1 }
            if bill.assignments.contains(where: { claim in
                claim.participants.contains(where: { $0 >= bill.participantCount }) || Set(claim.participants).count != claim.participants.count
            }) { strangersOrDuplicates += 1 }
            if session.canShare { canShare += 1 }
            if facts.isSettled, !session.canShare { blockedByTotals += 1 }
            if case let .percentage(percent, basis) = bill.sessionTip.configuration {
                let base = basis == .postTaxTotal ? bill.itemsSubtotalCents + bill.taxCents : bill.itemsSubtotalCents
                if base * percent % 100 == 50 { halfCentTip += 1 }
            }
        }
    }

    @Test("generated bills reach every case the properties are about")
    func generatedBillsAreNotVacuous() {
        var tally = Tally()
        for batch in 0 ..< 40 {
            for seed in PropertySeeds.seeds(inBatch: batch) { tally.add(GeneratedBill.random(seed: seed)) }
        }
        let n = tally.bills
        func atLeast(_ count: Int, percent: Int, _ what: String) {
            #expect(count * 100 >= n * percent, "only \(count) of \(n) generated bills have \(what); expected at least \(percent)%")
        }
        atLeast(tally.unitLeftover, percent: 8, "a leftover cent on a shared unit")
        atLeast(tally.taxLeftover, percent: 10, "a leftover cent of tax")
        atLeast(tally.tipLeftover, percent: 10, "a leftover cent of tip")
        atLeast(tally.sharedUnits, percent: 40, "a unit shared by several people")
        atLeast(tally.quantityLines, percent: 40, "a quantity line")
        atLeast(tally.unclaimed, percent: 12, "an unclaimed unit")
        atLeast(tally.settled, percent: 50, "every unit claimed")
        atLeast(tally.zeroItemPerson, percent: 15, "a person with no items")
        atLeast(tally.multipleTaxLines, percent: 15, "several tax lines")
        atLeast(tally.serviceCharge, percent: 10, "a service charge")
        atLeast(tally.printedTip, percent: 15, "a printed tip")
        atLeast(tally.customTip, percent: 10, "a custom tip")
        atLeast(tally.postTaxTip, percent: 10, "a post-tax tip basis")
        atLeast(tally.gappedOrShuffledOrder, percent: 15, "participants with gapped or shuffled orderIndex")
        atLeast(tally.strangersOrDuplicates, percent: 1, "unknown or repeated assignees")
        atLeast(tally.canShare, percent: 25, "a shareable split")
        atLeast(tally.blockedByTotals, percent: 5, "a fully claimed bill blocked by its printed totals")
        #expect(tally.halfCentTip > 0, "no generated percentage tip landed exactly on half a cent")
    }

    @Test("the committed reference corpus is varied too")
    func committedCorpusIsNotVacuous() throws {
        let corpus = try ReferenceCorpus.load(from: ReferenceCorpus.committedFixtureURL)
        var tally = Tally()
        for entry in corpus.bills { tally.add(entry.bill) }
        #expect(tally.unitLeftover >= 30 && tally.taxLeftover >= 30 && tally.tipLeftover >= 30)
        #expect(tally.sharedUnits >= 100 && tally.quantityLines >= 80)
        #expect(tally.unclaimed >= 30 && tally.settled >= 100 && tally.canShare >= 50 && tally.blockedByTotals >= 10)
        #expect(tally.zeroItemPerson >= 30 && tally.multipleTaxLines >= 30)
        #expect(tally.serviceCharge >= 20 && tally.printedTip >= 30 && tally.customTip >= 20 && tally.postTaxTip >= 20)
        #expect(tally.gappedOrShuffledOrder >= 20 && tally.strangersOrDuplicates >= 3)
        #expect(Set(corpus.bills.map(\.bill.participantCount)).isSuperset(of: [1, 2, 3, 4, 5, 6, 7, 8]))
    }
}
