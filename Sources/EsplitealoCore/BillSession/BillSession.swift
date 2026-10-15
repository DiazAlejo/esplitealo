import Foundation

public struct BillSession: Sendable, Equatable {
    /// Version of the JSON written by `BillSessionCoding`. Bump it (and add a fixture) when the stored shape changes.
    public static let currentSchemaVersion = 1

    public var draft: ReceiptDraft
    public var merchantName: String
    /// When the bill was made; formatted for display (and sharing) by the caller's calendar.
    public var date: Date?
    /// Gratuity printed on the receipt (distinct from session tip settings).
    public var serviceChargeCents: Int
    public var participants: [Participant]
    public var assignments: [ItemAssignment]
    public var tip: TipConfiguration
    public var mismatchAcknowledged: Bool

    public init(
        draft: ReceiptDraft,
        merchantName: String = "",
        date: Date? = nil,
        serviceChargeCents: Int = 0,
        participants: [Participant] = [],
        assignments: [ItemAssignment] = [],
        tip: TipConfiguration? = nil,
        mismatchAcknowledged: Bool = false
    ) {
        self.draft = ReceiptDraftEditing.reconcile(draft)
        self.merchantName = merchantName
        self.date = date
        self.serviceChargeCents = serviceChargeCents
        self.participants = participants
        self.assignments = assignments
        self.mismatchAcknowledged = mismatchAcknowledged
        if let tip {
            self.tip = tip
        } else if serviceChargeCents > 0 || (draft.tip?.minorUnits ?? 0) > 0 {
            self.tip = .percentage(percent: 0, basis: .preTaxSubtotal)
        } else {
            self.tip = .percentage(percent: 20, basis: .preTaxSubtotal)
        }
    }

    public var phase: BillSessionPhase {
        if participants.isEmpty { return .draft }
        if draft.total == nil { return .missingPrintedTotal }
        if !draft.reconciliation.reconciles, !mismatchAcknowledged { return .mismatch }
        if !unassignedUnits.isEmpty { return .needsAssignment }
        if canShare { return .ready }
        return .totals
    }

    public var shareBlockReason: ShareBlockReason? {
        if canShare { return nil }
        if draft.total == nil { return .missingPrintedTotal }
        if !unassignedUnits.isEmpty { return .unassignedItems }
        if hasUnallocatedAdjustments { return .discountNeedsManualAdjustment }
        return .receiptMismatch
    }

    public var canShare: Bool {
        guard draft.total != nil, !hasUnallocatedAdjustments else { return false }
        guard draft.reconciliation.reconciles, splitResult.isSettled, financialTotalsMatch else { return false }
        if let printed = printedReceiptTotalCents {
            return derivedBillTotalCents == printed + sessionTipCents
        }
        return false
    }

    public var hasUnallocatedAdjustments: Bool {
        draft.adjustments.contains { $0.amount.minorUnits != 0 }
    }

    public var netItemsSubtotalCents: Int {
        draft.items.reduce(0) { $0 + $1.lineTotal.minorUnits }
            + draft.adjustments.reduce(0) { $0 + $1.amount.minorUnits }
    }

    public var sessionTipCents: Int {
        let itemsSubtotal = netItemsSubtotalCents
        let tax = draft.tax?.minorUnits ?? 0
        return BillCalculator.tipAmount(tip: tip, itemsSubtotal: itemsSubtotal, taxCents: tax)
    }

    public var printedReceiptTotalCents: Int? {
        draft.total.map(\.minorUnits)
    }

    /// Tip/gratuity printed on the receipt (allocated across people; not session tip).
    public var receiptTipOnBillCents: Int {
        guard serviceChargeCents == 0 else { return 0 }
        return draft.tip?.minorUnits ?? 0
    }

    public var derivedBillTotalCents: Int {
        let tax = draft.tax?.minorUnits ?? 0
        return netItemsSubtotalCents + tax + serviceChargeCents + receiptTipOnBillCents + sessionTipCents
    }

    public var confirmedBillTotalCents: Int {
        derivedBillTotalCents
    }

    private var financialTotalsMatch: Bool {
        guard splitResult.isSettled else { return false }
        let sum = personBreakdowns.map(\.totalOwedCents).reduce(0, +)
        return sum == derivedBillTotalCents
    }

    public var splitResult: BillSplitResult {
        BillCalculator().calculate(receipt: calculatorReceipt)
    }

    public struct PersonBreakdown: Equatable, Sendable {
        public var participantID: UUID
        public var itemSubtotalCents: Int
        public var taxShareCents: Int
        public var serviceShareCents: Int
        public var receiptTipShareCents: Int
        public var tipShareCents: Int
        public var totalOwedCents: Int
        public var adjustments: [RoundingAdjustment]
    }

    public var personBreakdowns: [PersonBreakdown] {
        let split = splitResult
        let ordered = participants.sorted { $0.orderIndex < $1.orderIndex }
        let weights = ordered.map { participant in
            split.shares.first { $0.participantID == participant.id }?.itemSubtotalCents ?? 0
        }
        let serviceShares = SessionPoolAllocator.allocate(
            amount: serviceChargeCents,
            participants: ordered,
            weights: weights
        )
        let receiptTipShares = SessionPoolAllocator.allocate(
            amount: receiptTipOnBillCents,
            participants: ordered,
            weights: weights
        )
        return ordered.enumerated().map { offset, participant in
            let share = split.shares.first { $0.participantID == participant.id }
            let service = serviceShares[offset]
            let receiptTip = receiptTipShares[offset]
            let items = share?.itemSubtotalCents ?? 0
            let tax = share?.taxShareCents ?? 0
            let tipShare = share?.tipShareCents ?? 0
            return PersonBreakdown(
                participantID: participant.id,
                itemSubtotalCents: items,
                taxShareCents: tax,
                serviceShareCents: service,
                receiptTipShareCents: receiptTip,
                tipShareCents: tipShare,
                totalOwedCents: items + tax + service + receiptTip + tipShare,
                adjustments: share?.adjustments ?? []
            )
        }
    }

    public struct UnassignedUnit: Equatable, Sendable {
        public var itemID: UUID
        public var unitIndex: Int
    }

    public var unassignedUnits: [UnassignedUnit] {
        var out: [UnassignedUnit] = []
        let valid = Set(participants.map(\.id))
        for item in draft.items {
            for unitIndex in 0 ..< item.quantity {
                let ids = assignees(itemID: item.id, unitIndex: unitIndex).filter { valid.contains($0) }
                if ids.isEmpty {
                    out.append(UnassignedUnit(itemID: item.id, unitIndex: unitIndex))
                }
            }
        }
        return out
    }

    // MARK: - Receipt editing

    public mutating func applyDraft(_ draft: ReceiptDraft) {
        self.draft = ReceiptDraftEditing.reconcile(draft)
        pruneAssignments()
    }

    // MARK: - Participants

    @discardableResult
    public mutating func addParticipant(name: String) -> AddParticipantResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .emptyName }
        // One past the latest order, not the head count: after removals the count repeats an order
        // already in use, and the tie-break for leftover cents would stop following who was added first.
        let order = (participants.map(\.orderIndex).max() ?? -1) + 1
        participants.append(Participant(name: trimmed, orderIndex: order))
        return .added
    }

    public mutating func renameParticipant(id: UUID, name: String) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }
        let existing = participants[index]
        participants[index] = Participant(id: existing.id, name: name, orderIndex: existing.orderIndex)
    }

    @discardableResult
    public mutating func removeParticipant(id: UUID) -> RemoveParticipantResult {
        guard participants.contains(where: { $0.id == id }) else { return .notFound }
        guard participants.count > 1 else { return .lastParticipant }
        let assigned = assignments.filter { $0.participantIDs.contains(id) }
        if assigned.isEmpty {
            participants.removeAll { $0.id == id }
            pruneAssignments()
            return .removed
        }
        let unitCount = assigned.count
        let orphaned = orphanedUnitsIfRemoved(participantID: id)
        let shared = assigned.contains { $0.participantIDs.count > 1 }
        return .requiresConfirmation(
            assignedUnitCount: unitCount,
            orphanedUnitCount: orphaned.count,
            sharedAssignmentsRemain: shared
        )
    }

    public mutating func forceRemoveParticipant(id: UUID) {
        guard participants.count > 1 else { return }
        participants.removeAll { $0.id == id }
        assignments = assignments.compactMap { assignment in
            let remaining = assignment.participantIDs.filter { $0 != id }
            guard !remaining.isEmpty else { return nil }
            return ItemAssignment(
                itemID: assignment.itemID,
                unitIndex: assignment.unitIndex,
                participantIDs: remaining
            )
        }
        pruneAssignments()
    }

    // MARK: - Assignments

    public mutating func assignUnit(itemID: UUID, unitIndex: Int, participantIDs: [UUID]) {
        let valid = Set(participants.map(\.id))
        let unique = Array(Set(participantIDs.filter { valid.contains($0) }))
        setAssignment(itemID: itemID, unitIndex: unitIndex, participantIDs: unique)
    }

    public mutating func clearUnitAssignment(itemID: UUID, unitIndex: Int) {
        assignments.removeAll { $0.itemID == itemID && $0.unitIndex == unitIndex }
    }

    public mutating func splitRestEvenly() {
        let receipt = calculatorReceipt
        let updated = BillCalculator().splitRestEvenly(receipt: receipt)
        assignments = updated.assignments
    }

    public func preTaxSubtotalCents(for participantID: UUID) -> Int {
        personBreakdowns.first { $0.participantID == participantID }?.itemSubtotalCents ?? 0
    }

    public mutating func acknowledgeMismatch() {
        mismatchAcknowledged = true
    }

    // MARK: - Internals

    private var calculatorReceipt: Receipt {
        Receipt(
            items: draft.items.map {
                ReceiptItem(
                    id: $0.id,
                    description: $0.name,
                    quantity: $0.quantity,
                    totalPriceCents: $0.lineTotal.minorUnits
                )
            },
            taxCents: draft.tax?.minorUnits ?? 0,
            tip: tip,
            confirmedTotalCents: confirmedBillTotalCents,
            participants: participants,
            assignments: assignments
        )
    }

    private func assignees(itemID: UUID, unitIndex: Int) -> [UUID] {
        assignments.first { $0.itemID == itemID && $0.unitIndex == unitIndex }?.participantIDs ?? []
    }

    private mutating func setAssignment(itemID: UUID, unitIndex: Int, participantIDs: [UUID]) {
        assignments.removeAll { $0.itemID == itemID && $0.unitIndex == unitIndex }
        if !participantIDs.isEmpty {
            assignments.append(ItemAssignment(itemID: itemID, unitIndex: unitIndex, participantIDs: participantIDs))
        }
    }

    private mutating func pruneAssignments() {
        let itemIDs = Set(draft.items.map(\.id))
        let valid = Set(participants.map(\.id))
        assignments = assignments.compactMap { assignment in
            guard itemIDs.contains(assignment.itemID) else { return nil }
            guard assignment.unitIndex >= 0 else { return nil }
            let item = draft.items.first { $0.id == assignment.itemID }
            guard let item, assignment.unitIndex < item.quantity else { return nil }
            let ids = Array(Set(assignment.participantIDs.filter { valid.contains($0) }))
            guard !ids.isEmpty else { return nil }
            return ItemAssignment(
                itemID: assignment.itemID,
                unitIndex: assignment.unitIndex,
                participantIDs: ids
            )
        }
    }

    private func orphanedUnitsIfRemoved(participantID: UUID) -> [UnassignedUnit] {
        assignments.compactMap { assignment in
            guard assignment.participantIDs.contains(participantID) else { return nil }
            let remaining = assignment.participantIDs.filter { $0 != participantID }
            if remaining.isEmpty {
                return UnassignedUnit(itemID: assignment.itemID, unitIndex: assignment.unitIndex)
            }
            return nil
        }
    }
}
