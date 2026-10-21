import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension RGBAColor {
    public var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: alpha)
    }

    #if canImport(UIKit)
    fileprivate var platformColor: UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }
    #elseif canImport(AppKit)
    fileprivate var platformColor: NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }
    #endif
}

extension Color {
    /// A colour that follows the appearance of the view it is drawn in.
    public static func dynamic(light: RGBAColor, dark: RGBAColor, lightIncreased: RGBAColor? = nil, darkIncreased: RGBAColor? = nil) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let increased = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark { return (increased ? darkIncreased ?? dark : dark).platformColor }
            return (increased ? lightIncreased ?? light : light).platformColor
        })
        #elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark.platformColor : light.platformColor
        })
        #else
        light.color
        #endif
    }

    /// The Esplitéalo palette: `Color.esp.paper`, `Color.esp.primary`, ... Every role adapts to light and dark.
    public static var esp: EspColors { EspColors() }
}

/// Dynamic SwiftUI colours for every role in `DesignPalette`.
public struct EspColors: Sendable {
    fileprivate init() {}

    private func role(_ keyPath: KeyPath<DesignPalette, RGBAColor>) -> Color {
        .dynamic(
            light: DesignPalette.light[keyPath: keyPath],
            dark: DesignPalette.dark[keyPath: keyPath],
            lightIncreased: DesignPalette.palette(for: .light, contrast: .increased)[keyPath: keyPath],
            darkIncreased: DesignPalette.palette(for: .dark, contrast: .increased)[keyPath: keyPath]
        )
    }

    public var paper: Color { role(\.paper) }
    public var surface: Color { role(\.surface) }
    public var well: Color { role(\.well) }
    public var ink: Color { role(\.ink) }
    public var inkSecondary: Color { role(\.inkSecondary) }
    public var line: Color { role(\.line) }
    public var hairline: Color { role(\.hairline) }
    public var selection: Color { role(\.selection) }
    public var scrim: Color { role(\.scrim) }

    public var primary: Color { role(\.primary) }
    public var primaryLip: Color { role(\.primaryLip) }
    public var onPrimary: Color { role(\.onPrimary) }

    public var warn: Color { role(\.warn) }
    public var warnBackground: Color { role(\.warnBackground) }
    public var warnSoft: Color { role(\.warnSoft) }
    public var okBackground: Color { role(\.okBackground) }
    public var okSoft: Color { role(\.okSoft) }

    /// Shapes only. Text uses `pinkInk`.
    public var pink: Color { role(\.pink) }
    public var pinkInk: Color { role(\.pinkInk) }
    public var pinkSoft: Color { role(\.pinkSoft) }
    public var pinkMid: Color { role(\.pinkMid) }
    public var onPink: Color { role(\.onPink) }
}

extension PersonColorSlot {
    public var fillColor: Color { .dynamic(light: fill(in: .light), dark: fill(in: .dark)) }
    public var letterColor: Color { .dynamic(light: letter(in: .light), dark: letter(in: .dark)) }
}

extension View {
    /// The cream (or dark basil) paper behind a screen, with the green accent.
    public func espScreenBackground() -> some View {
        self
            .foregroundStyle(Color.esp.ink)
            .tint(Color.esp.primary)
            .background(Color.esp.paper.ignoresSafeArea())
    }
}
