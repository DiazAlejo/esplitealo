import Testing
@testable import EsplitealoDesign

/// Contrast the screens really draw that `ContrastTests` (the colour plan's own table) does not list, and the
/// Increase Contrast palette. Text needs 4.5:1, graphics and the outline of a control 3:1 (WCAG 2.2); with Increase
/// Contrast on, text needs 7:1 and graphics 4.5:1.
struct AccessibilityContrastTests {
    typealias Pair = ContrastTests.Pair

    /// Pairs found in the screens: secondary text on tinted banners, warn text on a card, a link on the OK tint.
    static let screenPairs: [Pair] = [
        Pair(name: "Secondary text on the OK tint", foreground: \.inkSecondary, background: \.okBackground, minimum: 4.5),
        Pair(name: "Secondary text on the soft OK tint", foreground: \.inkSecondary, background: \.okSoft, minimum: 4.5),
        Pair(name: "Secondary text on the warn banner", foreground: \.inkSecondary, background: \.warnBackground, minimum: 4.5),
        Pair(name: "Secondary text on the soft warn tint", foreground: \.inkSecondary, background: \.warnSoft, minimum: 4.5),
        Pair(name: "Warn text on the warn banner", foreground: \.warn, background: \.warnBackground, minimum: 4.5),
        Pair(name: "Warn text on a card", foreground: \.warn, background: \.surface, minimum: 4.5),
        Pair(name: "Green text on the soft OK tint", foreground: \.primary, background: \.okSoft, minimum: 4.5),
        Pair(name: "Body text on the soft warn tint", foreground: \.ink, background: \.warnSoft, minimum: 4.5),
        Pair(name: "Text field outline on paper", foreground: \.inkSecondary, background: \.paper, minimum: 3),
        Pair(name: "Text field outline on a sheet", foreground: \.inkSecondary, background: \.surface, minimum: 3),
        Pair(name: "Empty check circle on the selection well", foreground: \.inkSecondary, background: \.well, minimum: 3),
    ]

    static let appearances: [DesignAppearance] = [.light, .dark]

    @Test(arguments: screenPairs, appearances)
    func screenPairMeetsItsMinimum(pair: Pair, appearance: DesignAppearance) {
        let palette = DesignPalette.palette(for: appearance)
        let ratio = palette[keyPath: pair.foreground].contrastRatio(with: palette[keyPath: pair.background])
        #expect(ratio >= pair.minimum, "\(pair.name) in \(appearance): \(ratio) < \(pair.minimum)")
    }

    /// A person's colour is a graphic: it must be told apart from the surface it sits on, in both appearances.
    @Test(arguments: appearances)
    func personColoursStandOutFromEverySurface(appearance: DesignAppearance) {
        let palette = DesignPalette.palette(for: appearance)
        for slot in PersonColorSlot.allCases {
            let fill = slot.fill(in: appearance)
            for (name, surface) in [("paper", palette.paper), ("surface", palette.surface), ("well", palette.well)] {
                #expect(fill.contrastRatio(with: surface) >= 3, "\(slot) on \(name) in \(appearance)")
            }
        }
    }

    // MARK: Increase Contrast

    static let increasedContrastPairs: [Pair] = ContrastTests.pairs.map { pair in
        Pair(name: pair.name, foreground: pair.foreground, background: pair.background, minimum: pair.minimum >= 4.5 ? 7 : 4.5)
    } + screenPairs.filter { $0.minimum >= 4.5 }.map { pair in
        Pair(name: pair.name, foreground: pair.foreground, background: pair.background, minimum: 7)
    }

    @Test(arguments: increasedContrastPairs, appearances)
    func increaseContrastRaisesTextTo7AndGraphicsTo45(pair: Pair, appearance: DesignAppearance) {
        let palette = DesignPalette.palette(for: appearance, contrast: .increased)
        let ratio = palette[keyPath: pair.foreground].contrastRatio(with: palette[keyPath: pair.background])
        #expect(ratio >= pair.minimum, "\(pair.name) with Increase Contrast in \(appearance): \(ratio) < \(pair.minimum)")
    }

    @Test(arguments: appearances)
    func increaseContrastDrawsVisibleBordersAndRules(appearance: DesignAppearance) {
        let palette = DesignPalette.palette(for: appearance, contrast: .increased)
        for background in [palette.paper, palette.surface, palette.well] {
            #expect(palette.line.contrastRatio(with: background) >= 3, "card border in \(appearance)")
        }
        // A hairline is opaque, so its contrast does not depend on what is under it.
        #expect(palette.hairline.alpha == 1)
        #expect(palette.hairline.contrastRatio(with: palette.surface) >= 3, "row rule in \(appearance)")
    }

    @Test(arguments: appearances)
    func increaseContrastKeepsTheBrandAndTheOtherRoles(appearance: DesignAppearance) {
        let standard = DesignPalette.palette(for: appearance)
        let increased = DesignPalette.palette(for: appearance, contrast: .increased)
        #expect(increased.paper == standard.paper)
        #expect(increased.surface == standard.surface)
        #expect(increased.ink == standard.ink)
        #expect(increased.onPrimary == standard.onPrimary)
        #expect(DesignPalette.palette(for: appearance, contrast: .standard) == standard)
    }
}
