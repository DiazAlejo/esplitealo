import Foundation

public struct Participant: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let name: String
    /// Zero-based order in which the participant was added (earlier wins tie-breaks).
    public let orderIndex: Int

    public init(id: UUID = UUID(), name: String, orderIndex: Int) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
    }
}
