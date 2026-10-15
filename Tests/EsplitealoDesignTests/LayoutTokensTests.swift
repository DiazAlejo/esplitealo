import Testing
@testable import EsplitealoDesign

struct LayoutTokensTests {
    @Test func spacingUsesAFourPointBase() {
        #expect(Spacing.all == [4, 8, 12, 16, 24, 32])
        #expect(Spacing.screenMargin == 16)
    }

    @Test func shapesFollowTheGuide() {
        #expect(Radius.card == 16)
        #expect(Radius.sheet == 24)
        #expect(Radius.smallButton == 12)
        #expect(Stroke.hairline == 1)
    }

    @Test func tapTargetsAreAtLeast44Points() {
        #expect(TapTarget.minimum == 44)
        #expect(TapTarget.primaryButtonHeight >= 52)
        #expect(TapTarget.secondaryButtonHeight >= 44)
    }

    @Test func pressedButtonsDarkenAndShrinkSlightly() {
        #expect(PressFeedback.brightness == 0.8)
        #expect(PressFeedback.scale == 0.97)
        #expect(PressFeedback.duration == 0.1)
    }
}
