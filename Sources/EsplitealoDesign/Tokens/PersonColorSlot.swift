import Foundation

/// The eight person colours (tokens.css section 4), ordered for distinguishability: two to four people, the usual
/// bill, get the most different colours. Never green, pink or warn red-orange. Colour never stands alone: every chip
/// also shows an initial and the name.
public enum PersonColorSlot: Int, Sendable, Hashable, CaseIterable {
    case denim, ochre, plum, umber, lagoon, stone, heather, slate

    public var name: String {
        switch self {
        case .denim: "Denim"
        case .ochre: "Ochre"
        case .plum: "Plum"
        case .umber: "Umber"
        case .lagoon: "Lagoon"
        case .stone: "Stone"
        case .heather: "Heather"
        case .slate: "Slate"
        }
    }

    public func fill(in appearance: DesignAppearance) -> RGBAColor {
        switch appearance {
        case .light: RGBAColor(hex: [0x5070B2, 0x72650F, 0x572F5F, 0x634521, 0x146579, 0x5E5A54, 0x77618F, 0x363D4B][rawValue])
        case .dark: RGBAColor(hex: [0x9BBAF7, 0xD9CE8D, 0xAF89B6, 0xBCA07F, 0x7CB9CA, 0xCDC9C2, 0xD6C2EE, 0x979EAC][rawValue])
        }
    }

    /// The initial's colour: white on the light fills, dark paper on the dark tints.
    public func letter(in appearance: DesignAppearance) -> RGBAColor {
        switch appearance {
        case .light: RGBAColor(hex: 0xFFFFFF)
        case .dark: RGBAColor(hex: 0x111915)
        }
    }

    /// Each added person takes the next free slot, so v1 needs no colour picker.
    public init(participantIndex: Int) {
        let count = Self.allCases.count
        self = Self(rawValue: ((participantIndex % count) + count) % count)!
    }

    /// Beyond eight people colours repeat, so the ring switches style instead of silently reusing a look.
    public static func usesDottedRing(participantIndex: Int) -> Bool {
        participantIndex >= allCases.count
    }
}

public enum PersonInitial {
    /// First letter of the trimmed name, uppercased; "?" when there is no name yet.
    public static func make(from name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "?" }
        return String(first).uppercased()
    }
}
