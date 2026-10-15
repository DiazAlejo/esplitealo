import Foundation

/// A stored bill written by a newer app than this one, or one that cannot be trusted.
public enum BillSessionDecodingError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(found: Int)
}

/// The one JSON dialect used to store a bill: ISO 8601 dates, sorted keys.
public enum BillSessionCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension BillSession: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case draft
        case merchantName
        case date
        case serviceChargeCents
        case participants
        case assignments
        case tip
        case mismatchAcknowledged
    }

    /// Restores a bill exactly as it was saved: the draft is not re-reconciled and nothing is pruned,
    /// so a restored bill always equals the one that was written.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version >= 1, version <= Self.currentSchemaVersion else {
            throw BillSessionDecodingError.unsupportedSchemaVersion(found: version)
        }
        draft = try container.decode(ReceiptDraft.self, forKey: .draft)
        merchantName = try container.decode(String.self, forKey: .merchantName)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        serviceChargeCents = try container.decode(Int.self, forKey: .serviceChargeCents)
        participants = try container.decode([Participant].self, forKey: .participants)
        assignments = try container.decode([ItemAssignment].self, forKey: .assignments)
        tip = try container.decode(TipConfiguration.self, forKey: .tip)
        mismatchAcknowledged = try container.decode(Bool.self, forKey: .mismatchAcknowledged)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(draft, forKey: .draft)
        try container.encode(merchantName, forKey: .merchantName)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encode(serviceChargeCents, forKey: .serviceChargeCents)
        try container.encode(participants, forKey: .participants)
        try container.encode(assignments, forKey: .assignments)
        try container.encode(tip, forKey: .tip)
        try container.encode(mismatchAcknowledged, forKey: .mismatchAcknowledged)
    }
}
