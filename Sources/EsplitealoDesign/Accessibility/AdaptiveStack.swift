import SwiftUI

/// When rows put their parts side by side and when they stack them.
public enum AdaptiveLayoutPolicy {
    /// Stacked from `threshold` (xxxLarge by default) up. A row that is tight even at xLarge (a text field and its
    /// button) asks for `.xLarge`.
    public static func stacks(dynamicTypeSize: DynamicTypeSize, from threshold: DynamicTypeSize = .xxxLarge) -> Bool {
        dynamicTypeSize >= threshold
    }
}

/// Its children side by side, or one above the other when the text is large. Unlike `ViewThatFits` it decides from the
/// text size, and it keeps the same views in both layouts (`AnyLayout`): they stay the same elements, with the same
/// identity, which is how XCUITest's Dynamic Type audit can see that the text scales.
///
/// Give the first child `.frame(maxWidth: .infinity, alignment: .leading)` where a `Spacer` would have pushed the
/// rest to the end of the row. The closure says whether the row is stacked, for the few children that differ.
public struct AdaptiveStack<Content: View>: View {
    private let rowAlignment: VerticalAlignment
    private let stackedAlignment: HorizontalAlignment
    private let rowSpacing: CGFloat?
    private let stackedSpacing: CGFloat?
    private let threshold: DynamicTypeSize
    private let content: (Bool) -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        rowAlignment: VerticalAlignment = .center,
        stackedAlignment: HorizontalAlignment = .leading,
        rowSpacing: CGFloat? = nil,
        stackedSpacing: CGFloat? = nil,
        stacksFrom threshold: DynamicTypeSize = .xxxLarge,
        @ViewBuilder content: @escaping (_ isStacked: Bool) -> Content
    ) {
        self.rowAlignment = rowAlignment
        self.stackedAlignment = stackedAlignment
        self.rowSpacing = rowSpacing
        self.stackedSpacing = stackedSpacing ?? rowSpacing
        self.threshold = threshold
        self.content = content
    }

    public init(
        rowAlignment: VerticalAlignment = .center,
        stackedAlignment: HorizontalAlignment = .leading,
        rowSpacing: CGFloat? = nil,
        stackedSpacing: CGFloat? = nil,
        stacksFrom threshold: DynamicTypeSize = .xxxLarge,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(rowAlignment: rowAlignment, stackedAlignment: stackedAlignment, rowSpacing: rowSpacing,
                  stackedSpacing: stackedSpacing, stacksFrom: threshold) { _ in content() }
    }

    public var body: some View {
        let stacked = AdaptiveLayoutPolicy.stacks(dynamicTypeSize: dynamicTypeSize, from: threshold)
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: stackedAlignment, spacing: stackedSpacing))
            : AnyLayout(HStackLayout(alignment: rowAlignment, spacing: rowSpacing))
        layout { content(stacked) }
    }
}
