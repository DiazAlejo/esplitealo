import Testing
@testable import EsplitealoDesign

/// The documented contrast table on the colour plan page (`design/mockups/_src/colors.tpl.html`, "brand" rows):
/// text pairs need 4.5:1, graphics and controls 3:1 (WCAG 2.2). Both appearances must pass every row.
struct ContrastTests {
    struct Pair: Sendable, CustomStringConvertible {
        let name: String
        let foreground: KeyPath<DesignPalette, RGBAColor> & Sendable
        let background: KeyPath<DesignPalette, RGBAColor> & Sendable
        let minimum: Double
        var description: String { name }
    }

    static let pairs: [Pair] = [
        Pair(name: "Body text", foreground: \.ink, background: \.paper, minimum: 4.5),
        Pair(name: "Body text on card or sheet", foreground: \.ink, background: \.surface, minimum: 4.5),
        Pair(name: "Body text on well", foreground: \.ink, background: \.well, minimum: 4.5),
        Pair(name: "Secondary text", foreground: \.inkSecondary, background: \.paper, minimum: 4.5),
        Pair(name: "Secondary text on card", foreground: \.inkSecondary, background: \.surface, minimum: 4.5),
        Pair(name: "Secondary text on well", foreground: \.inkSecondary, background: \.well, minimum: 4.5),
        Pair(name: "Links, quiet buttons", foreground: \.primary, background: \.paper, minimum: 4.5),
        Pair(name: "Links on card", foreground: \.primary, background: \.surface, minimum: 4.5),
        Pair(name: "Primary button label", foreground: \.onPrimary, background: \.primary, minimum: 4.5),
        Pair(name: "Warn text on paper", foreground: \.warn, background: \.paper, minimum: 4.5),
        Pair(name: "Warn text on its tinted row", foreground: \.warn, background: \.warnSoft, minimum: 4.5),
        Pair(name: "Body text on warn banner", foreground: \.ink, background: \.warnBackground, minimum: 4.5),
        Pair(name: "Green text on the OK tint", foreground: \.primary, background: \.okBackground, minimum: 4.5),
        Pair(name: "Body text on the OK tint", foreground: \.ink, background: \.okBackground, minimum: 4.5),
        Pair(name: "Text-safe pink on paper", foreground: \.pinkInk, background: \.paper, minimum: 4.5),
        Pair(name: "Text-safe pink on card", foreground: \.pinkInk, background: \.surface, minimum: 4.5),
        Pair(name: "Graphic: pink on paper", foreground: \.pink, background: \.paper, minimum: 3),
        Pair(name: "Graphic: pink on card", foreground: \.pink, background: \.surface, minimum: 3),
        Pair(name: "Graphic: green on paper", foreground: \.primary, background: \.paper, minimum: 3),
        Pair(name: "Graphic: warn glyph on its tint", foreground: \.warn, background: \.warnSoft, minimum: 3),
    ]

    // Pink on the cream paper is 3.15:1 and on the dark paper 5.3:1 (colours plan, "NEVER small text").
    // The plan page also documents that the light-mode pink does not reach 4.5:1, which is why `pinkInk` exists.
    static let appearances: [DesignAppearance] = [.light, .dark]

    @Test(arguments: pairs, appearances)
    func pairMeetsItsDocumentedMinimum(pair: Pair, appearance: DesignAppearance) {
        let palette = DesignPalette.palette(for: appearance)
        let ratio = palette[keyPath: pair.foreground].contrastRatio(with: palette[keyPath: pair.background])
        #expect(ratio >= pair.minimum, "\(pair.name) in \(appearance): \(ratio) < \(pair.minimum)")
    }

    @Test func documentedPinkRatios() {
        let light = DesignPalette.light
        let dark = DesignPalette.dark
        #expect(abs(light.pink.contrastRatio(with: light.paper) - 3.15) < 0.05)
        #expect(abs(dark.pink.contrastRatio(with: dark.paper) - 5.3) < 0.05)
        #expect(abs(light.pinkInk.contrastRatio(with: light.paper) - 5.1) < 0.1)
        // Pink on the green button is 1.56:1, so the button never carries pink directly.
        #expect(abs(light.pink.contrastRatio(with: light.primary) - 1.56) < 0.05)
    }

    @Test func divisionMarkOnTheButtonCoinIsReadable() {
        // The coin is `on-primary` (white / dark ink) with the pink ÷ inside: 3.4:1 on white, 5.9:1 on dark ink.
        let light = DesignPalette.light
        let dark = DesignPalette.dark
        #expect(light.pink.contrastRatio(with: light.onPrimary) >= 3)
        #expect(dark.pink.contrastRatio(with: dark.onPrimary) >= 3)
    }

    @Test(arguments: appearances)
    func personColorsKeepTheirLettersReadable(appearance: DesignAppearance) {
        for slot in PersonColorSlot.allCases {
            let fill = slot.fill(in: appearance)
            let letter = slot.letter(in: appearance)
            #expect(fill.contrastRatio(with: letter) >= 4.5, "\(slot) letter in \(appearance)")
        }
    }

    @Test func lightPersonFillsAlsoPassTheGraphicsRuleOnPaper() {
        let paper = DesignPalette.light.paper
        for slot in PersonColorSlot.allCases {
            #expect(slot.fill(in: .light).contrastRatio(with: paper) >= 3, "\(slot)")
        }
    }
}
