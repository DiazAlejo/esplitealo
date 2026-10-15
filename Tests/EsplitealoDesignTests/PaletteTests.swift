import Testing
@testable import EsplitealoDesign

/// Values are copied from `design/mockups/_src/tokens.css`, the only file that defines the brand colours.
struct PaletteTests {
    @Test func brandInputsMatchTokens() {
        let light = DesignPalette.light
        #expect(light.paper.hexString == "#FBF7EF")
        #expect(light.primary.hexString == "#1F7A5A")
        #expect(light.primaryLip.hexString == "#145A42")
        #expect(light.pink.hexString == "#EA5A78")

        let dark = DesignPalette.dark
        #expect(dark.paper.hexString == "#111915")
        #expect(dark.primary.hexString == "#4CC59A")
        #expect(dark.primaryLip.hexString == "#2E9C77")
        #expect(dark.pink.hexString == "#EA5A78")
    }

    @Test func neutralsAndStatusMatchTokens() {
        let light = DesignPalette.light
        #expect(light.surface.hexString == "#FFFDF8")
        #expect(light.well.hexString == "#F1EADB")
        #expect(light.ink.hexString == "#1F2A24")
        #expect(light.inkSecondary.hexString == "#5C665F")
        #expect(light.line.hexString == "#DDD3BE")
        #expect(light.onPrimary.hexString == "#FFFFFF")
        #expect(light.warn.hexString == "#C23A1D")
        #expect(light.warnBackground.hexString == "#FCEBDD")
        #expect(light.warnSoft.hexString == "#FDEEE2")

        let dark = DesignPalette.dark
        #expect(dark.surface.hexString == "#1A2420")
        #expect(dark.well.hexString == "#232F29")
        #expect(dark.ink.hexString == "#F4EFE4")
        #expect(dark.inkSecondary.hexString == "#A8B3AA")
        #expect(dark.line.hexString == "#33423A")
        #expect(dark.onPrimary.hexString == "#0E1F18")
        #expect(dark.warn.hexString == "#FF8466")
        #expect(dark.warnBackground.hexString == "#3C2718")
        #expect(dark.warnSoft.hexString == "#30231A")
    }

    @Test func pinkRolesAreDerivedFromTheBrandPink() {
        #expect(DesignPalette.light.pinkInk.hexString == "#B0445A")
        #expect(DesignPalette.light.pinkSoft.hexString == "#FCE8EC")
        #expect(DesignPalette.light.pinkMid.hexString == "#F3A4B5")
        #expect(DesignPalette.light.onPink.hexString == "#2B0F17")
        // On the dark paper the pink itself passes 4.5:1, so it is also the text-safe pink.
        #expect(DesignPalette.dark.pinkInk == DesignPalette.dark.pink)
        #expect(DesignPalette.dark.pinkSoft.hexString == "#4D2630")
        #expect(DesignPalette.dark.pinkMid.hexString == "#934050")
    }

    @Test func greenTintsMixThePrimaryIntoTheSurface() {
        #expect(DesignPalette.light.okBackground.hexString == "#EBF1EA")
        let dark = DesignPalette.dark
        let expected = dark.primary.mixed(with: dark.surface, fraction: 0.17)
        #expect(dark.okBackground == expected)
    }

    @Test func paletteLookupFollowsTheAppearance() {
        #expect(DesignPalette.palette(for: .light) == DesignPalette.light)
        #expect(DesignPalette.palette(for: .dark) == DesignPalette.dark)
    }

    @Test func pinkNeverChangesBetweenAppearances() {
        #expect(DesignPalette.light.pink == DesignPalette.dark.pink)
    }
}
