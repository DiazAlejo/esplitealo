import Foundation

/// An sRGB colour as 8-bit channels plus an alpha. Free of SwiftUI so tokens can be tested (contrast, mixing)
/// on any platform; `Color.dynamic(light:dark:)` turns pairs of these into SwiftUI colours.
public struct RGBAColor: Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: Double

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: UInt8((hex >> 16) & 0xFF),
            green: UInt8((hex >> 8) & 0xFF),
            blue: UInt8(hex & 0xFF),
            alpha: alpha
        )
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// CSS `color-mix(in srgb, self fraction, other)`: `fraction` is the share of `self`.
    public func mixed(with other: RGBAColor, fraction: Double) -> RGBAColor {
        func channel(_ a: UInt8, _ b: UInt8) -> UInt8 {
            let value = Double(a) * fraction + Double(b) * (1 - fraction)
            return UInt8(max(0, min(255, value.rounded())))
        }
        return RGBAColor(
            red: channel(red, other.red),
            green: channel(green, other.green),
            blue: channel(blue, other.blue),
            alpha: alpha * fraction + other.alpha * (1 - fraction)
        )
    }

    /// WCAG 2.x relative luminance of the opaque colour.
    public var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.x contrast ratio, from 1 (identical) to 21 (black on white). Ignores alpha.
    public func contrastRatio(with other: RGBAColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
