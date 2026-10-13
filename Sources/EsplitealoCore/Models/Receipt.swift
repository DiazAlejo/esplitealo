import Foundation

public enum TipBasis: Equatable, Sendable {
    case preTaxSubtotal
    case postTaxTotal
}

public enum TipConfiguration: Equatable, Sendable {
    case percentage(percent: Int, basis: TipBasis)
    case custom(cents: Int)
}

public struct Receipt: Equatable, Sendable {
    public let items: [ReceiptItem]
    public let taxCents: Int
    public let tip: TipConfiguration
    public let confirmedTotalCents: Int
    public let participants: [Participant]
    public let assignments: [ItemAssignment]

    public init(
        items: [ReceiptItem],
        taxCents: Int,
        tip: TipConfiguration,
        confirmedTotalCents: Int,
        participants: [Participant],
        assignments: [ItemAssignment]
    ) {
        self.items = items
        self.taxCents = taxCents
        self.tip = tip
        self.confirmedTotalCents = confirmedTotalCents
        self.participants = participants
        self.assignments = assignments
    }
}
