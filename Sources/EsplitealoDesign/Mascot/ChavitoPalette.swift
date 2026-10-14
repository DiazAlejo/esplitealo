/// An sRGB colour as 8-bit channels. Kept free of SwiftUI so tokens can be tested and written to SVG.
public struct ChavitoColor: Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    public var hexString: String {
        func pair(_ v: UInt8) -> String {
            let digits = Array("0123456789ABCDEF")
            return String([digits[Int(v >> 4)], digits[Int(v & 0xF)]])
        }
        return "#" + pair(red) + pair(green) + pair(blue)
    }
}

public enum ChavitoAppearance: Sendable, Hashable, CaseIterable {
    case light
    case dark
}

/// Roles map to `--m-*` tokens in `design/mockups/_src/tokens.css` section 6.
public enum ChavitoColorRole: Sendable, Hashable, CaseIterable {
    case fur, furShade, mask, cream, cheek, nose, tear, white
    /// The big soft pink disc behind Chavito (`--disc-hero`, i.e. `--pink-soft`).
    case disc
}

public struct ChavitoPalette: Equatable, Sendable {
    public var fur: ChavitoColor
    public var furShade: ChavitoColor
    public var mask: ChavitoColor
    public var cream: ChavitoColor
    public var cheek: ChavitoColor
    public var nose: ChavitoColor
    public var tear: ChavitoColor
    public var white: ChavitoColor
    public var disc: ChavitoColor
    /// App paper the artwork sits on; only used by exports that need a ground.
    public var ground: ChavitoColor

    // Illustration colours are constant across appearances (tokens.css defines `--m-*` once, pink is the same
    // #EA5A78 in dark); only the soft disc and the ground change.
    public static let light = ChavitoPalette(
        fur: ChavitoColor(hex: 0x9AA5B1),
        furShade: ChavitoColor(hex: 0x5A6470),
        mask: ChavitoColor(hex: 0x2B333D),
        cream: ChavitoColor(hex: 0xF5EEDF),
        cheek: ChavitoColor(hex: 0xEA5A78),
        nose: ChavitoColor(hex: 0xEA5A78),
        tear: ChavitoColor(hex: 0x7FC4E8),
        white: ChavitoColor(hex: 0xFFFFFF),
        disc: ChavitoColor(hex: 0xFCE8EC),
        ground: ChavitoColor(hex: 0xFBF7EF)
    )

    public static let dark = ChavitoPalette(
        fur: light.fur,
        furShade: light.furShade,
        mask: light.mask,
        cream: light.cream,
        cheek: light.cheek,
        nose: light.nose,
        tear: light.tear,
        white: light.white,
        disc: ChavitoColor(hex: 0x4D2630),
        ground: ChavitoColor(hex: 0x0F2A21)
    )

    public static func palette(for appearance: ChavitoAppearance) -> ChavitoPalette {
        appearance == .dark ? dark : light
    }

    public func color(for role: ChavitoColorRole) -> ChavitoColor {
        switch role {
        case .fur: fur
        case .furShade: furShade
        case .mask: mask
        case .cream: cream
        case .cheek: cheek
        case .nose: nose
        case .tear: tear
        case .white: white
        case .disc: disc
        }
    }
}
