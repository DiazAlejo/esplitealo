import Testing
@testable import EsplitealoDesign

struct RGBAColorTests {
    @Test func parsesAndPrintsHex() {
        let color = RGBAColor(hex: 0xFBF7EF)
        #expect(color.red == 0xFB)
        #expect(color.green == 0xF7)
        #expect(color.blue == 0xEF)
        #expect(color.alpha == 1)
        #expect(color.hexString == "#FBF7EF")
    }

    @Test func mixesLikeCSSColorMixInSRGB() {
        // color-mix(in srgb, #EA5A78 75%, #000)
        let pinkInk = RGBAColor(hex: 0xEA5A78).mixed(with: RGBAColor(hex: 0x000000), fraction: 0.75)
        #expect(pinkInk.hexString == "#B0445A")
        // color-mix(in srgb, #EA5A78 14%, #fff)
        let pinkSoft = RGBAColor(hex: 0xEA5A78).mixed(with: RGBAColor(hex: 0xFFFFFF), fraction: 0.14)
        #expect(pinkSoft.hexString == "#FCE8EC")
    }

    @Test func contrastRatioMatchesWCAGReferenceValues() {
        let black = RGBAColor(hex: 0x000000)
        let white = RGBAColor(hex: 0xFFFFFF)
        #expect(abs(black.contrastRatio(with: white) - 21) < 0.0001)
        #expect(abs(white.contrastRatio(with: black) - 21) < 0.0001)
        #expect(abs(white.contrastRatio(with: white) - 1) < 0.0001)
        // #777 on white is the textbook 4.48:1 pair.
        #expect(abs(RGBAColor(hex: 0x777777).contrastRatio(with: white) - 4.48) < 0.01)
    }
}
