import Foundation

/// Assignment for one unit of a quantity line. Empty `participantIDs` means unclaimed.
public struct ItemAssignment: Equatable, Sendable, Codable {
    public let itemID: UUID
    public let unitIndex: Int
    public let participantIDs: [UUID]

    public init(itemID: UUID, unitIndex: Int, participantIDs: [UUID]) {
        self.itemID = itemID
        self.unitIndex = unitIndex
        self.participantIDs = participantIDs
    }
}
