import SwiftUI
import Testing
@testable import EsplitealoDesign

/// Rows that put things side by side at ordinary sizes stack them at large sizes. The decision is made from the text
/// size alone (not by measuring what fits, as `ViewThatFits` does): measuring swaps one view tree for another when the
/// size changes, which XCUITest's Dynamic Type audit reads as text that does not scale. The same views in a different
/// layout (`AnyLayout`) are the same elements, and they scale.
struct AdaptiveLayoutPolicyTests {
    @Test(arguments: DynamicTypeSize.allCases)
    func rowsStackFromTheDefaultThresholdUp(size: DynamicTypeSize) {
        #expect(AdaptiveLayoutPolicy.stacks(dynamicTypeSize: size) == (size >= .xxxLarge))
    }

    @Test(arguments: DynamicTypeSize.allCases)
    func aTightRowCanAskToStackSooner(size: DynamicTypeSize) {
        #expect(AdaptiveLayoutPolicy.stacks(dynamicTypeSize: size, from: .xLarge) == (size >= .xLarge))
    }

    @Test func theDefaultSizeNeverStacks() {
        #expect(!AdaptiveLayoutPolicy.stacks(dynamicTypeSize: .large))
        #expect(AdaptiveLayoutPolicy.stacks(dynamicTypeSize: .accessibility1))
    }
}
