import EsplitealoCore
import Foundation

public struct GroundTruthItem: Codable, Equatable, Sendable {
    public var name: String
    public var quantity: Int
    public var lineTotalMinor: Int

    public init(name: String, quantity: Int = 1, lineTotalMinor: Int) {
        self.name = name
        self.quantity = max(1, quantity)
        self.lineTotalMinor = lineTotalMinor
    }
}

/// Expected receipt fields for benchmark scoring (minor units, USD).
public struct ReceiptGroundTruth: Codable, Equatable, Sendable {
    public var id: String
    public var items: [GroundTruthItem]
    public var subtotalMinor: Int?
    public var taxMinor: Int?
    public var tipMinor: Int?
    public var totalMinor: Int?
    /// When set, reconciliation agreement compares `ReceiptDraft.reconciles` to this value.
    public var expectsReconciles: Bool?

    public init(
        id: String,
        items: [GroundTruthItem],
        subtotalMinor: Int? = nil,
        taxMinor: Int? = nil,
        tipMinor: Int? = nil,
        totalMinor: Int? = nil,
        expectsReconciles: Bool? = nil
    ) {
        self.id = id
        self.items = items
        self.subtotalMinor = subtotalMinor
        self.taxMinor = taxMinor
        self.tipMinor = tipMinor
        self.totalMinor = totalMinor
        self.expectsReconciles = expectsReconciles
    }
}
