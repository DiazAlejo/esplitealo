import SwiftUI
import Testing
@testable import EsplitealoDesign

/// Bars pinned to the top or bottom of a screen are for people with room to spare: at the biggest text sizes and in
/// landscape on a phone they would cover the content, so they scroll with it instead.
struct ChromePolicyTests {
    static let sizes = DynamicTypeSize.allCases

    @Test(arguments: sizes)
    func aHeaderIsPinnedOnlyUpToXXLargeAndInPortrait(size: DynamicTypeSize) {
        #expect(ChromePolicy.pinsHeader(dynamicTypeSize: size, verticalSizeClass: .regular) == (size <= .xxLarge))
        #expect(ChromePolicy.pinsHeader(dynamicTypeSize: size, verticalSizeClass: nil) == (size <= .xxLarge))
        #expect(!ChromePolicy.pinsHeader(dynamicTypeSize: size, verticalSizeClass: .compact))
    }

    @Test(arguments: sizes)
    func aSingleButtonBarStaysPinnedUntilTheTwoLargestSizes(size: DynamicTypeSize) {
        let covers = size >= .accessibility4
        #expect(ChromePolicy.pinsActionBar(dynamicTypeSize: size, verticalSizeClass: .regular) == !covers)
        // Landscape keeps one button in reach: it is only 56 pt.
        #expect(ChromePolicy.pinsActionBar(dynamicTypeSize: size, verticalSizeClass: .compact) == !covers)
    }

    @Test(arguments: sizes)
    func aBarWithSeveralButtonsScrollsFromXXXLargeAndInLandscape(size: DynamicTypeSize) {
        #expect(ChromePolicy.pinsExtraActions(dynamicTypeSize: size, verticalSizeClass: .regular) == (size <= .xxLarge))
        #expect(!ChromePolicy.pinsExtraActions(dynamicTypeSize: size, verticalSizeClass: .compact))
    }

    @Test func theDefaultSizeKeepsEverythingPinnedInPortrait() {
        #expect(ChromePolicy.pinsHeader(dynamicTypeSize: .large, verticalSizeClass: .regular))
        #expect(ChromePolicy.pinsActionBar(dynamicTypeSize: .large, verticalSizeClass: .regular))
        #expect(ChromePolicy.pinsExtraActions(dynamicTypeSize: .large, verticalSizeClass: .regular))
    }

    @Test func xxxLargeScrollsTheExtrasSoAnIPhoneSEKeepsRoomForTheContent() {
        #expect(ChromePolicy.pinsHeader(dynamicTypeSize: .xxLarge, verticalSizeClass: .regular))
        #expect(!ChromePolicy.pinsHeader(dynamicTypeSize: .xxxLarge, verticalSizeClass: .regular))
        #expect(!ChromePolicy.pinsExtraActions(dynamicTypeSize: .xxxLarge, verticalSizeClass: .regular))
        #expect(ChromePolicy.pinsActionBar(dynamicTypeSize: .xxxLarge, verticalSizeClass: .regular))
    }

    @Test func accessibility3KeepsTheMainButtonPinnedButNothingElse() {
        #expect(!ChromePolicy.pinsHeader(dynamicTypeSize: .accessibility3, verticalSizeClass: .regular))
        #expect(ChromePolicy.pinsActionBar(dynamicTypeSize: .accessibility3, verticalSizeClass: .regular))
        #expect(!ChromePolicy.pinsExtraActions(dynamicTypeSize: .accessibility3, verticalSizeClass: .regular))
    }

    @Test func accessibility5ScrollsEverything() {
        #expect(!ChromePolicy.pinsActionBar(dynamicTypeSize: .accessibility5, verticalSizeClass: .regular))
    }
}
