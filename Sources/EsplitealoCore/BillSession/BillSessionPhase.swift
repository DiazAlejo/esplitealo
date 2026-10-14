import Foundation

public enum BillSessionPhase: Equatable, Sendable {
    case draft
    case missingPrintedTotal
    case mismatch
    case needsAssignment
    case totals
    case ready
}

public enum ShareBlockReason: Equatable, Sendable {
    case missingPrintedTotal
    case receiptMismatch
    case unassignedItems
    case discountNeedsManualAdjustment
}

public enum AddParticipantResult: Equatable, Sendable {
    case added
    case emptyName
}

public enum RemoveParticipantResult: Equatable, Sendable {
    case removed
    case requiresConfirmation(assignedUnitCount: Int, orphanedUnitCount: Int, sharedAssignmentsRemain: Bool)
    case notFound
    case lastParticipant
}

public enum ShareLanguage: String, Equatable, Sendable {
    case es
    case en
}
