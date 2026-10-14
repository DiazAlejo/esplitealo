import Foundation

public struct RoundingAdjustment: Equatable, Sendable {
    public enum Pool: Equatable, Sendable {
        case itemUnit(itemID: UUID, unitIndex: Int)
        case tax
        case tip
    }

    public let participantID: UUID
    public let pool: Pool
    /// Always `1` for a single leftover cent granted by largest remainder.
    public let cents: Int

    public init(participantID: UUID, pool: Pool, cents: Int = 1) {
        self.participantID = participantID
        self.pool = pool
        self.cents = cents
    }
}

public struct ParticipantShare: Equatable, Sendable {
    public let participantID: UUID
    public let itemSubtotalCents: Int
    public let taxShareCents: Int
    public let tipShareCents: Int
    public let amountOwedCents: Int
    public let adjustments: [RoundingAdjustment]
}

public struct BillSplitResult: Equatable, Sendable {
    public let shares: [ParticipantShare]
    public let isSettled: Bool
    public let calculatedTotalCents: Int
    public let confirmedTotalCents: Int
    public let totalsMatch: Bool
    public let tipCents: Int
    public let allAdjustments: [RoundingAdjustment]
}

public struct BillCalculator: Sendable {
    public init() {}

    public func calculate(receipt: Receipt) -> BillSplitResult {
        let participants = Self.orderedParticipants(receipt)
        let participantIndexByID = Dictionary(
            uniqueKeysWithValues: participants.enumerated().map { ($1.id, $0) }
        )

        var adjustments: [RoundingAdjustment] = []
        var itemSubtotals = Array(repeating: 0, count: participants.count)
        var isSettled = true

        for item in receipt.items {
            let unitPrices = Self.unitPrices(lineTotal: item.totalPriceCents, quantity: item.quantity)
            for unitIndex in 0 ..< item.quantity {
                let price = unitPrices[unitIndex]
                let assigneeIDs = Self.assignees(for: item.id, unitIndex: unitIndex, in: receipt.assignments)
                let assigneeIndices = Set(assigneeIDs.compactMap { participantIndexByID[$0] }).sorted()
                if assigneeIndices.isEmpty {
                    isSettled = false
                    continue
                }
                let assigneeParticipants = assigneeIndices.map { participants[$0] }
                let weights = assigneeParticipants.map { _ in 1 }
                let pool = RoundingAdjustment.Pool.itemUnit(itemID: item.id, unitIndex: unitIndex)
                let (unitShares, unitAdj) = Self.allocate(
                    amount: price,
                    recipients: assigneeParticipants,
                    weights: weights,
                    pool: pool
                )
                for (idx, share) in zip(assigneeIndices, unitShares) {
                    itemSubtotals[idx] += share
                }
                adjustments.append(contentsOf: unitAdj)
            }
        }

        let itemsSubtotal = receipt.items.reduce(0) { $0 + $1.totalPriceCents }
        let tipCents = Self.tipAmount(tip: receipt.tip, itemsSubtotal: itemsSubtotal, taxCents: receipt.taxCents)
        let calculatedTotal = itemsSubtotal + receipt.taxCents + tipCents
        let totalsMatch = calculatedTotal == receipt.confirmedTotalCents

        let (taxShares, taxAdj) = Self.allocate(
            amount: receipt.taxCents,
            recipients: participants,
            weights: itemSubtotals,
            pool: .tax
        )
        adjustments.append(contentsOf: taxAdj)

        let (tipShares, tipAdj) = Self.allocate(
            amount: tipCents,
            recipients: participants,
            weights: itemSubtotals,
            pool: .tip
        )
        adjustments.append(contentsOf: tipAdj)

        let shares = participants.enumerated().map { offset, participant in
            let itemSub = itemSubtotals[offset]
            let tax = taxShares[offset]
            let tip = tipShares[offset]
            let personAdj = adjustments.filter { $0.participantID == participant.id }
            return ParticipantShare(
                participantID: participant.id,
                itemSubtotalCents: itemSub,
                taxShareCents: tax,
                tipShareCents: tip,
                amountOwedCents: itemSub + tax + tip,
                adjustments: personAdj
            )
        }

        return BillSplitResult(
            shares: shares,
            isSettled: isSettled,
            calculatedTotalCents: calculatedTotal,
            confirmedTotalCents: receipt.confirmedTotalCents,
            totalsMatch: totalsMatch,
            tipCents: tipCents,
            allAdjustments: adjustments
        )
    }

    /// Assign every still-unclaimed unit to all participants (equal split per unit).
    public func splitRestEvenly(receipt: Receipt) -> Receipt {
        let allIDs = Self.orderedParticipants(receipt).map(\.id)
        let validIDs = Set(allIDs)
        var assignmentMap = Dictionary(
            receipt.assignments.map { (Self.assignmentKey(itemID: $0.itemID, unitIndex: $0.unitIndex), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for item in receipt.items {
            for unitIndex in 0 ..< item.quantity {
                let key = Self.assignmentKey(itemID: item.id, unitIndex: unitIndex)
                let existing = (assignmentMap[key]?.participantIDs ?? []).filter(validIDs.contains)
                if existing.isEmpty {
                    assignmentMap[key] = ItemAssignment(itemID: item.id, unitIndex: unitIndex, participantIDs: allIDs)
                }
            }
        }

        let merged = assignmentMap.values.sorted {
            if $0.itemID != $1.itemID { return $0.itemID.uuidString < $1.itemID.uuidString }
            return $0.unitIndex < $1.unitIndex
        }
        return Receipt(
            items: receipt.items,
            taxCents: receipt.taxCents,
            tip: receipt.tip,
            confirmedTotalCents: receipt.confirmedTotalCents,
            participants: receipt.participants,
            assignments: Array(merged)
        )
    }

    // MARK: - Internals

    static func orderedParticipants(_ receipt: Receipt) -> [Participant] {
        var seen = Set<UUID>()
        return receipt.participants
            .sorted { $0.orderIndex < $1.orderIndex }
            .filter { seen.insert($0.id).inserted }
    }

    static func unitPrices(lineTotal: Int, quantity: Int) -> [Int] {
        let q = max(1, quantity)
        let base = lineTotal / q
        let extra = lineTotal % q
        return (0 ..< q).map { index in base + (index < extra ? 1 : 0) }
    }

    static func tipAmount(tip: TipConfiguration, itemsSubtotal: Int, taxCents: Int) -> Int {
        switch tip {
        case let .custom(cents):
            return max(0, cents)
        case let .percentage(percent, basis):
            let basisAmount =
                switch basis {
                case .preTaxSubtotal: itemsSubtotal
                case .postTaxTotal: itemsSubtotal + taxCents
                }
            let p = max(0, percent)
            return (basisAmount * p + 50) / 100
        }
    }

    static func assignees(for itemID: UUID, unitIndex: Int, in assignments: [ItemAssignment]) -> [UUID] {
        assignments.first { $0.itemID == itemID && $0.unitIndex == unitIndex }?.participantIDs ?? []
    }

    static func assignmentKey(itemID: UUID, unitIndex: Int) -> String {
        "\(itemID.uuidString)-\(unitIndex)"
    }

    /// Largest-remainder allocation across `recipients` with parallel `weights`.
    static func allocate(
        amount: Int,
        recipients: [Participant],
        weights: [Int],
        pool: RoundingAdjustment.Pool
    ) -> (shares: [Int], adjustments: [RoundingAdjustment]) {
        let n = recipients.count
        guard n > 0 else { return ([], []) }
        var shares = Array(repeating: 0, count: n)
        if amount == 0 { return (shares, []) }

        let totalWeight = weights.reduce(0, +)
        if totalWeight == 0 { return (shares, []) }

        var fractional: [(index: Int, remainder: Int, order: Int)] = []
        var distributed = 0
        for index in 0 ..< n {
            let w = weights[index]
            guard w > 0 else { continue }
            let numerator = amount * w
            let floorShare = numerator / totalWeight
            let rem = numerator % totalWeight
            shares[index] = floorShare
            distributed += floorShare
            fractional.append((index, rem, recipients[index].orderIndex))
        }

        var leftover = amount - distributed
        fractional.sort { lhs, rhs in
            if lhs.remainder != rhs.remainder { return lhs.remainder > rhs.remainder }
            return lhs.order < rhs.order
        }

        var adjustments: [RoundingAdjustment] = []
        var cursor = 0
        while leftover > 0, cursor < fractional.count {
            let index = fractional[cursor].index
            shares[index] += 1
            adjustments.append(
                RoundingAdjustment(participantID: recipients[index].id, pool: pool, cents: 1)
            )
            leftover -= 1
            cursor += 1
        }

        return (shares, adjustments)
    }
}
