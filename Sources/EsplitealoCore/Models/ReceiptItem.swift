import Foundation

public struct ReceiptItem: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let description: String
    public let quantity: Int
    public let totalPriceCents: Int

    public init(id: UUID = UUID(), description: String, quantity: Int, totalPriceCents: Int) {
        self.id = id
        self.description = description
        self.quantity = max(1, quantity)
        self.totalPriceCents = totalPriceCents
    }
}
