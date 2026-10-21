import Foundation

public enum DesignAppearance: Sendable, Hashable, CaseIterable {
    case light
    case dark
}

/// Every colour role of the app, per appearance. The values mirror `design/mockups/_src/tokens.css`
/// (the only file that defines colours); change both together. The pink rules from that file apply:
/// pink is only a shape, an icon accent, decoration or a large soft disc; text uses `pinkInk`; warn always
/// comes with an icon or words and never as a big fill; green is the action colour; person colours only
/// appear on avatars, dots and bars.
/// Whether the person turned on Increase Contrast (Settings > Accessibility > Display & Text Size).
public enum DesignContrast: Sendable, Hashable, CaseIterable {
    case standard
    case increased
}

public struct DesignPalette: Equatable, Sendable {
    // Brand inputs
    public var paper: RGBAColor
    public var primary: RGBAColor
    public var primaryLip: RGBAColor
    public var pink: RGBAColor

    // Neutrals and status
    public var surface: RGBAColor
    public var well: RGBAColor
    public var ink: RGBAColor
    public var inkSecondary: RGBAColor
    public var line: RGBAColor
    public var onPrimary: RGBAColor
    public var warn: RGBAColor
    public var warnBackground: RGBAColor
    public var warnSoft: RGBAColor
    public var okBackground: RGBAColor
    public var okSoft: RGBAColor
    public var hairline: RGBAColor
    public var selection: RGBAColor
    public var scrim: RGBAColor

    // Pink roles
    public var pinkInk: RGBAColor
    public var pinkSoft: RGBAColor
    public var pinkMid: RGBAColor
    public var onPink: RGBAColor

    private init(
        paper: RGBAColor, primary: RGBAColor, primaryLip: RGBAColor, pink: RGBAColor,
        surface: RGBAColor, well: RGBAColor, ink: RGBAColor, inkSecondary: RGBAColor, line: RGBAColor,
        onPrimary: RGBAColor, warn: RGBAColor, warnBackground: RGBAColor, warnSoft: RGBAColor,
        okTintStrong: Double, okTintSoft: Double,
        hairline: RGBAColor, selection: RGBAColor, scrim: RGBAColor,
        pinkInk: RGBAColor, pinkSoft: RGBAColor, pinkMid: RGBAColor, onPink: RGBAColor
    ) {
        self.paper = paper
        self.primary = primary
        self.primaryLip = primaryLip
        self.pink = pink
        self.surface = surface
        self.well = well
        self.ink = ink
        self.inkSecondary = inkSecondary
        self.line = line
        self.onPrimary = onPrimary
        self.warn = warn
        self.warnBackground = warnBackground
        self.warnSoft = warnSoft
        self.okBackground = primary.mixed(with: surface, fraction: okTintStrong)
        self.okSoft = primary.mixed(with: surface, fraction: okTintSoft)
        self.hairline = hairline
        self.selection = selection
        self.scrim = scrim
        self.pinkInk = pinkInk
        self.pinkSoft = pinkSoft
        self.pinkMid = pinkMid
        self.onPink = onPink
    }

    public static let light: DesignPalette = {
        let pink = RGBAColor(hex: 0xEA5A78)
        return DesignPalette(
            paper: RGBAColor(hex: 0xFBF7EF),
            primary: RGBAColor(hex: 0x1F7A5A),
            primaryLip: RGBAColor(hex: 0x145A42),
            pink: pink,
            surface: RGBAColor(hex: 0xFFFDF8),
            well: RGBAColor(hex: 0xF1EADB),
            ink: RGBAColor(hex: 0x1F2A24),
            inkSecondary: RGBAColor(hex: 0x5C665F),
            line: RGBAColor(hex: 0xDDD3BE),
            onPrimary: RGBAColor(hex: 0xFFFFFF),
            warn: RGBAColor(hex: 0xC23A1D),
            warnBackground: RGBAColor(hex: 0xFCEBDD),
            warnSoft: RGBAColor(hex: 0xFDEEE2),
            okTintStrong: 0.09,
            okTintSoft: 0.08,
            hairline: RGBAColor(hex: 0x1F2A24, alpha: 0.11),
            selection: RGBAColor(hex: 0x1F2A24, alpha: 0.055),
            scrim: RGBAColor(hex: 0x111915, alpha: 0.46),
            pinkInk: pink.mixed(with: RGBAColor(hex: 0x000000), fraction: 0.75),
            pinkSoft: pink.mixed(with: RGBAColor(hex: 0xFFFFFF), fraction: 0.14),
            pinkMid: pink.mixed(with: RGBAColor(hex: 0xFFFFFF), fraction: 0.55),
            onPink: RGBAColor(hex: 0x2B0F17)
        )
    }()

    public static let dark: DesignPalette = {
        let pink = RGBAColor(hex: 0xEA5A78)
        let paper = RGBAColor(hex: 0x111915)
        return DesignPalette(
            paper: paper,
            primary: RGBAColor(hex: 0x4CC59A),
            primaryLip: RGBAColor(hex: 0x2E9C77),
            pink: pink,
            surface: RGBAColor(hex: 0x1A2420),
            well: RGBAColor(hex: 0x232F29),
            ink: RGBAColor(hex: 0xF4EFE4),
            inkSecondary: RGBAColor(hex: 0xA8B3AA),
            line: RGBAColor(hex: 0x33423A),
            onPrimary: RGBAColor(hex: 0x0E1F18),
            warn: RGBAColor(hex: 0xFF8466),
            warnBackground: RGBAColor(hex: 0x3C2718),
            warnSoft: RGBAColor(hex: 0x30231A),
            okTintStrong: 0.17,
            okTintSoft: 0.11,
            hairline: RGBAColor(hex: 0xFFFFFF, alpha: 0.10),
            selection: RGBAColor(hex: 0xFFFFFF, alpha: 0.07),
            scrim: RGBAColor(hex: 0x000000, alpha: 0.6),
            // On the dark paper the pink itself passes 4.5:1, so it is also the text-safe pink.
            pinkInk: pink,
            pinkSoft: pink.mixed(with: RGBAColor(hex: 0x1B1519), fraction: 0.24),
            pinkMid: pink.mixed(with: paper, fraction: 0.60),
            onPink: RGBAColor(hex: 0x2B0F17)
        )
    }()

    public static func palette(for appearance: DesignAppearance) -> DesignPalette {
        switch appearance {
        case .light: light
        case .dark: dark
        }
    }

    /// The palette for an appearance, with Increase Contrast applied: text reaches 7:1 (AAA), graphics 4.5:1, and the
    /// borders and rules of cards and rows are drawn solid so they can be seen (3:1). The paper, the surfaces, the ink and
    /// the text on the green button keep their values; only the secondary ink, the brand green, the warn colour, the
    /// pink and the lines change. Person colours already pass 3:1 on every surface and do not change.
    public static func palette(for appearance: DesignAppearance, contrast: DesignContrast) -> DesignPalette {
        let base = palette(for: appearance)
        guard contrast == .increased else { return base }
        var palette = base
        switch appearance {
        case .light:
            palette.inkSecondary = RGBAColor(hex: 0x2E3933)
            palette.primary = RGBAColor(hex: 0x14543C)
            palette.primaryLip = RGBAColor(hex: 0x0C3A2A)
            palette.warn = RGBAColor(hex: 0x8E2410)
            palette.line = RGBAColor(hex: 0x857A63)
            palette.pink = RGBAColor(hex: 0xC8284E)
            palette.pinkInk = RGBAColor(hex: 0x230D12)
            palette.selection = RGBAColor(hex: 0x1F2A24, alpha: 0.09)
            palette.okBackground = palette.primary.mixed(with: palette.surface, fraction: 0.09)
            palette.okSoft = palette.primary.mixed(with: palette.surface, fraction: 0.08)
        case .dark:
            palette.inkSecondary = RGBAColor(hex: 0xE1E0D6)
            palette.primary = RGBAColor(hex: 0x92EBC8)
            palette.primaryLip = RGBAColor(hex: 0x4CC59A)
            palette.warn = RGBAColor(hex: 0xFFA690)
            palette.line = RGBAColor(hex: 0x71867A)
            palette.pink = RGBAColor(hex: 0xFF8CA6)
            palette.pinkInk = RGBAColor(hex: 0xFF8CA6)
            palette.selection = RGBAColor(hex: 0xFFFFFF, alpha: 0.11)
            palette.okBackground = palette.primary.mixed(with: palette.surface, fraction: 0.17)
            palette.okSoft = palette.primary.mixed(with: palette.surface, fraction: 0.11)
        }
        palette.hairline = palette.line
        return palette
    }

    // MARK: Pink uses (tokens.css section 3b). Each use points at one pink so it can be retired on its own.

    /// Current step in the progress dots; "Paso 2 de 5" is the second signal.
    public var stepNow: RGBAColor { pink }
    public var stepDone: RGBAColor { primary }
    /// Assign progress bar and the processing bar.
    public var meterFill: RGBAColor { pink }
    /// Selected state: tip segment underline, selected chip underline, selected row rail.
    public var pick: RGBAColor { pink }
    public var focusRing: RGBAColor { pink }
    public var totalMark: RGBAColor { pink }
    /// The round chip on a primary button and the pink ÷ inside it.
    public var coinBackground: RGBAColor { onPrimary }
    public var coinMark: RGBAColor { pink }
}
