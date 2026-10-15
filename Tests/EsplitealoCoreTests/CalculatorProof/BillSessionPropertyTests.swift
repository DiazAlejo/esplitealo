import Foundation
import Testing
@testable import EsplitealoCore

extension BillSession {
    /// Item subtotals carry the weights every pool is allocated by; zero everywhere means nothing can be allocated.
    var hasAllocatableWeight: Bool {
        splitResult.shares.contains { $0.itemSubtotalCents > 0 }
    }

    /// Breakdown of the person at `position` of a generated bill.
    func breakdown(of position: Int) -> PersonBreakdown {
        personBreakdowns.first { $0.participantID == GeneratedBill.participantID(position) }!
    }
}

/// Property tests of `BillSession` (everything the screens read) over seeded, generated bills.
@Suite("CalculatorProof: BillSession properties")
struct CalculatorProofSessionProperties {
    // MARK: - Totals

    @Test("the bill total is the sum of its parts and every person's total is the sum of theirs", arguments: PropertySeeds.batches)
    func totalsAreSumsOfParts(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let facts = BillFacts(bill)
            let session = bill.session()
            let id = bill.seed
            let receiptTip = bill.serviceChargeCents > 0 ? 0 : (bill.printedTipCents ?? 0)

            expectProperty(session.sessionTipCents == facts.tipCents, seed: id, "session tip \(session.sessionTipCents) != rule \(facts.tipCents)")
            expectProperty(session.receiptTipOnBillCents == receiptTip, seed: id, "printed tip is allocated on top of a service charge, or dropped")
            expectProperty(
                session.derivedBillTotalCents == bill.itemsSubtotalCents + bill.taxCents + bill.serviceChargeCents + receiptTip + facts.tipCents,
                seed: id, "derived total is not items + tax + service + printed tip + session tip"
            )
            expectProperty(session.confirmedBillTotalCents == session.derivedBillTotalCents, seed: id, "confirmed total is not the derived total")
            expectProperty(session.splitResult.tipCents == session.sessionTipCents, seed: id, "calculator and session disagree on the tip")

            for breakdown in session.personBreakdowns {
                expectProperty(
                    breakdown.totalOwedCents == breakdown.itemSubtotalCents + breakdown.taxShareCents + breakdown.serviceShareCents
                        + breakdown.receiptTipShareCents + breakdown.tipShareCents,
                    seed: id, "person total is not the sum of their parts"
                )
                expectProperty(
                    min(breakdown.itemSubtotalCents, breakdown.taxShareCents, breakdown.serviceShareCents,
                        breakdown.receiptTipShareCents, breakdown.tipShareCents, breakdown.totalOwedCents) >= 0,
                    seed: id, "negative share"
                )
            }
            if session.hasAllocatableWeight {
                let breakdowns = session.personBreakdowns
                expectProperty(breakdowns.map(\.taxShareCents).reduce(0, +) == bill.taxCents, seed: id, "tax shares != tax")
                expectProperty(breakdowns.map(\.serviceShareCents).reduce(0, +) == bill.serviceChargeCents, seed: id, "service shares != service charge")
                expectProperty(breakdowns.map(\.receiptTipShareCents).reduce(0, +) == receiptTip, seed: id, "printed tip shares != printed tip")
                expectProperty(breakdowns.map(\.tipShareCents).reduce(0, +) == facts.tipCents, seed: id, "tip shares != tip")
                if facts.isSettled {
                    expectProperty(
                        breakdowns.map(\.totalOwedCents).reduce(0, +) == session.derivedBillTotalCents,
                        seed: id, "settled bill: people do not owe exactly the derived total"
                    )
                }
            }
        }
    }

    @Test("the session agrees with the calculator on items, tax, tip and rounding adjustments", arguments: PropertySeeds.batches)
    func sessionAgreesWithCalculator(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            let session = bill.session()
            let split = BillCalculator().calculate(receipt: bill.receipt())
            for position in 0 ..< bill.participantCount {
                let share = split.shares(for: bill)[position]
                let breakdown = session.breakdown(of: position)
                expectProperty(
                    breakdown.itemSubtotalCents == share.itemSubtotalCents && breakdown.taxShareCents == share.taxShareCents
                        && breakdown.tipShareCents == share.tipShareCents && breakdown.adjustments == share.adjustments,
                    seed: bill.seed, "session and calculator disagree for person \(position)"
                )
            }
        }
    }

    @Test("a person with no items owes no tax, service charge, printed tip or tip", arguments: PropertySeeds.batches)
    func personWithoutItemsOwesNothing(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            for breakdown in bill.session().personBreakdowns where breakdown.itemSubtotalCents == 0 {
                expectProperty(breakdown.totalOwedCents == 0, seed: bill.seed, "person with no items owes \(breakdown.totalOwedCents)")
            }
        }
    }

    // MARK: - Sharing

    @Test("an unclaimed unit always blocks sharing and the ready phase", arguments: PropertySeeds.batches)
    func unclaimedBlocksSharing(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed, printed: .consistent)
            let facts = BillFacts(bill)
            let session = bill.session()
            expectProperty(session.unassignedUnits.count == facts.unclaimedUnits, seed: bill.seed, "unassignedUnits disagrees with the generated claims")
            if !facts.isSettled {
                expectProperty(!session.canShare, seed: bill.seed, "bill with unclaimed units can be shared")
                expectProperty(session.phase != .ready && session.phase != .totals, seed: bill.seed, "unclaimed bill reached phase \(session.phase)")
                expectProperty(!session.splitResult.isSettled, seed: bill.seed, "unclaimed bill is settled")
            }
            if session.canShare {
                expectProperty(
                    facts.isSettled && session.draft.reconciliation.reconciles && session.phase == .ready
                        && session.personBreakdowns.map(\.totalOwedCents).reduce(0, +) == session.derivedBillTotalCents
                        && session.derivedBillTotalCents == (session.printedReceiptTotalCents ?? Int.min) + session.sessionTipCents,
                    seed: bill.seed, "canShare without its preconditions"
                )
            }
        }
    }

    @Test("a fully claimed bill whose printed amounts add up can be shared; changing the printed total blocks it", arguments: PropertySeeds.batches)
    func consistentBillsAreShareable(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed, claims: .full, printed: .consistent)
            let session = bill.session()
            guard session.hasAllocatableWeight else { continue }
            expectProperty(session.canShare, seed: bill.seed, "consistent, fully claimed bill cannot be shared (reason \(String(describing: session.shareBlockReason)))")
            expectProperty(session.phase == .ready && session.shareBlockReason == nil, seed: bill.seed, "phase \(session.phase)")

            var rng = SplitMix64(seed: seed ^ 0x0FF)
            var off = bill
            off.printedTotalCents = (bill.printedTotalCents ?? 0) + rng.pick([-500, -1, 1, 7, 250])
            expectProperty(!off.session().canShare, seed: bill.seed, "printed total off by a cent or more can still be shared")
            var noTotal = bill
            noTotal.printedTotalCents = nil
            expectProperty(
                !noTotal.session().canShare && noTotal.session().shareBlockReason == .missingPrintedTotal,
                seed: bill.seed, "a missing printed total did not block sharing"
            )
        }
    }

    @Test("splitting the rest evenly makes a consistent bill shareable", arguments: PropertySeeds.batches)
    func splitRestEvenlyFinishesTheBill(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed, claims: .any, printed: .consistent)
            var session = bill.session()
            let before = session.assignments
            session.splitRestEvenly()
            expectProperty(session.unassignedUnits.isEmpty, seed: bill.seed, "units still unassigned")
            expectProperty(session.hasAllocatableWeight == (bill.itemsSubtotalCents > 0), seed: bill.seed, "weight mismatch after splitting the rest")
            if session.hasAllocatableWeight {
                expectProperty(session.canShare && session.phase == .ready, seed: bill.seed, "bill not shareable after splitRestEvenly (\(session.phase))")
            }
            // Units that were already claimed keep their people.
            let facts = BillFacts(bill)
            for (item, units) in facts.assignees.enumerated() {
                for (unit, who) in units.enumerated() where !who.isEmpty {
                    let now = session.assignments.first { $0.itemID == GeneratedBill.itemID(item) && $0.unitIndex == unit }
                    let was = before.first { $0.itemID == GeneratedBill.itemID(item) && $0.unitIndex == unit }
                    expectProperty(now == was, seed: bill.seed, "claimed unit \(item).\(unit) was rewritten")
                }
            }
        }
    }

    // MARK: - Participant order

    @Test("the array order of participants never matters; orderIndex does", arguments: PropertySeeds.batches)
    func arrayOrderDoesNotMatter(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let bill = GeneratedBill.random(seed: seed)
            var rng = SplitMix64(seed: seed ^ 0xA5)
            var shuffled = bill.session()
            shuffled.participants = rng.shuffled(shuffled.participants)
            shuffled.assignments = rng.shuffled(shuffled.assignments)
            expectProperty(bill.session().personBreakdowns == shuffled.personBreakdowns, seed: bill.seed, "shuffling participants changed the breakdowns")
            expectProperty(bill.session().derivedBillTotalCents == shuffled.derivedBillTotalCents, seed: bill.seed, "shuffling participants changed the total")
        }
    }

    // MARK: - Editing sequences

    @Test("add/remove/assign/split sequences keep order, assignments and totals consistent", arguments: PropertySeeds.batches)
    func editSequencesKeepInvariants(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            var rng = SplitMix64(seed: seed)
            let bill = GeneratedBill.random(seed: seed, claims: .full, printed: .consistent)
            var session = BillSession(
                draft: bill.draft(), serviceChargeCents: bill.serviceChargeCents, tip: bill.sessionTip.configuration
            )
            for index in 0 ..< rng.between(1, 3) { session.addParticipant(name: "Start \(index)") }
            var gone: [UUID] = []

            for step in 0 ..< 40 {
                let context = "step \(step)"
                switch rng.below(10) {
                case 0, 1:
                    session.addParticipant(name: "Added \(step)")
                case 2:
                    if session.participants.count > 1 {
                        let victim = rng.pick(session.participants).id
                        session.forceRemoveParticipant(id: victim)
                        gone.append(victim)
                    }
                case 3:
                    let victim = rng.pick(session.participants).id
                    if case .removed = session.removeParticipant(id: victim) { gone.append(victim) }
                case 4, 5, 6:
                    guard !session.draft.items.isEmpty else { break }
                    let item = rng.pick(session.draft.items)
                    let unit = rng.below(item.quantity)
                    var who = session.participants.filter { _ in rng.chance(45) }.map(\.id)
                    if rng.chance(15), let stale = gone.last { who.append(stale) }
                    session.assignUnit(itemID: item.id, unitIndex: unit, participantIDs: who)
                case 7:
                    if let item = session.draft.items.first, rng.chance(50) {
                        session.clearUnitAssignment(itemID: item.id, unitIndex: rng.below(item.quantity))
                    } else {
                        session.splitRestEvenly()
                    }
                case 8:
                    session.tip = rng.chance(50) ? .percentage(percent: rng.pick([0, 15, 18, 20]), basis: rng.chance(50) ? .postTaxTotal : .preTaxSubtotal) : .custom(cents: rng.pick([0, 333, 1500]))
                default:
                    editDraft(&session, &rng)
                }
                // One report per seed is enough: a broken invariant stays broken for the rest of the sequence.
                if !checkInvariants(session, seed: bill.seed, context: context) { break }
            }
        }
    }

    private func editDraft(_ session: inout BillSession, _ rng: inout SplitMix64) {
        var draft = session.draft
        switch rng.below(3) {
        case 0:
            draft = ReceiptDraftEditing.addItem(to: draft, name: "New", unitPriceCents: rng.between(1, 3000), quantity: rng.between(1, 4))
        case 1:
            if let item = draft.items.last { draft = ReceiptDraftEditing.deleteItem(in: draft, itemID: item.id) }
        default:
            if let item = draft.items.first {
                draft = ReceiptDraftEditing.updateItem(in: draft, itemID: item.id, name: item.name, unitPriceCents: rng.between(1, 3000), quantity: rng.between(1, 5))
            }
        }
        session.applyDraft(draft)
    }

    private func checkInvariants(_ session: BillSession, seed: String, context: String) -> Bool {
        var ok = true
        func check(_ holds: @autoclosure () -> Bool, _ what: @autoclosure () -> String) {
            ok = expectProperty(holds(), seed: seed, "\(context): \(what())") && ok
        }
        let orders = session.participants.map(\.orderIndex)
        check(zip(orders, orders.dropFirst()).allSatisfy { $0 < $1 }, "orderIndex \(orders) does not follow the order people were added")

        let validPeople = Set(session.participants.map(\.id))
        let units = Dictionary(uniqueKeysWithValues: session.draft.items.map { ($0.id, $0.quantity) })
        for assignment in session.assignments {
            check(
                (units[assignment.itemID].map { assignment.unitIndex >= 0 && assignment.unitIndex < $0 } ?? false)
                    && !assignment.participantIDs.isEmpty && Set(assignment.participantIDs).isSubset(of: validPeople)
                    && Set(assignment.participantIDs).count == assignment.participantIDs.count,
                "assignment points at a missing item, unit or person, or is empty or duplicated"
            )
        }

        let claimed = Set(session.assignments.map { "\($0.itemID)-\($0.unitIndex)" })
        let expectedUnclaimed = session.draft.items.reduce(0) { sum, item in
            sum + (0 ..< item.quantity).filter { !claimed.contains("\(item.id)-\($0)") }.count
        }
        check(session.unassignedUnits.count == expectedUnclaimed, "unassignedUnits is wrong")
        check(session.personBreakdowns.map(\.participantID) == session.participants.map(\.id), "breakdowns are not in the order people were added")
        check(session.confirmedBillTotalCents == session.derivedBillTotalCents, "confirmed != derived")
        if session.canShare { check(session.phase == .ready, "canShare but phase \(session.phase)") }
        if expectedUnclaimed == 0, session.hasAllocatableWeight {
            check(
                session.personBreakdowns.map(\.totalOwedCents).reduce(0, +) == session.derivedBillTotalCents,
                "people do not owe the derived total"
            )
        }
        if expectedUnclaimed > 0 { check(!session.canShare, "canShare with unclaimed units") }
        return ok
    }

    // MARK: - Persistence and reproducibility

    @Test("saving and restoring a bill keeps every amount", arguments: PropertySeeds.batches)
    func codableRoundTripKeepsAmounts(batch: Int) throws {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let session = GeneratedBill.random(seed: seed).session()
            let restored = try BillSessionCoding.decoder().decode(BillSession.self, from: BillSessionCoding.encoder().encode(session))
            expectProperty(restored == session, seed: String(seed), "round trip changed the session")
            expectProperty(
                restored.personBreakdowns == session.personBreakdowns && restored.derivedBillTotalCents == session.derivedBillTotalCents
                    && restored.canShare == session.canShare,
                seed: String(seed), "round trip changed an amount"
            )
        }
    }

    @Test("the same seed always gives the same session and the same breakdowns", arguments: PropertySeeds.batches)
    func reproducibleFromSeed(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            let first = GeneratedBill.random(seed: seed).session()
            let second = GeneratedBill.random(seed: seed).session()
            expectProperty(first == second && first.personBreakdowns == second.personBreakdowns, seed: String(seed), "session is not reproducible from its seed")
        }
    }
}

/// Participant order is the tie-break for every leftover cent, so it must be the order people were added.
@Suite("CalculatorProof: participant order")
struct CalculatorProofParticipantOrder {
    @Test("a person added after earlier removals is ordered after everyone already on the bill")
    func addingAfterRemovalKeepsInsertionOrder() {
        var session = BillSession(draft: ReceiptDraft(items: [DraftItem(name: "Two cents", quantity: 1, lineTotal: DraftAmount(minorUnits: 2))]))
        for name in ["A", "B", "C", "D"] { session.addParticipant(name: name) }
        session.forceRemoveParticipant(id: session.participants[0].id) // A
        session.forceRemoveParticipant(id: session.participants[0].id) // B
        session.addParticipant(name: "E")
        session.addParticipant(name: "F")
        #expect(session.participants.map(\.name) == ["C", "D", "E", "F"])

        let orders = session.participants.map(\.orderIndex)
        #expect(zip(orders, orders.dropFirst()).allSatisfy { $0 < $1 }, "orderIndex \(orders) must increase with the order people were added")

        // Two cents shared by all four: the earliest two (C, D) get one cent each.
        session.assignUnit(itemID: session.draft.items[0].id, unitIndex: 0, participantIDs: session.participants.map(\.id))
        let cents = session.personBreakdowns.map(\.itemSubtotalCents)
        #expect(cents == [1, 1, 0, 0], "leftover cents went to \(cents) instead of the two earliest participants")
    }

    @Test("orderIndex follows insertion order through any add/remove sequence", arguments: PropertySeeds.batches)
    func insertionOrderThroughRandomSequences(batch: Int) {
        for seed in PropertySeeds.seeds(inBatch: batch) {
            var rng = SplitMix64(seed: seed)
            var session = BillSession(draft: ReceiptDraft())
            var added: [UUID] = []
            for step in 0 ..< 40 {
                if session.participants.count > 1, rng.chance(35) {
                    let victim = rng.pick(session.participants).id
                    session.forceRemoveParticipant(id: victim)
                    added.removeAll { $0 == victim }
                } else {
                    session.addParticipant(name: "P\(step)")
                    added.append(session.participants.last!.id)
                }
                let orders = session.participants.map(\.orderIndex)
                let inOrder = expectProperty(session.participants.map(\.id) == added, seed: String(seed), "step \(step): array is not in insertion order")
                let increasing = expectProperty(zip(orders, orders.dropFirst()).allSatisfy { $0 < $1 }, seed: String(seed), "step \(step): orderIndex \(orders) is not strictly increasing")
                if !(inOrder && increasing) { break }
            }
        }
    }
}
