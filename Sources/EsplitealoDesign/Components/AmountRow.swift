import SwiftUI

/// A line with a description and an amount, for the rows of an `EspCard` (receipt items, totals). The description
/// wraps instead of truncating, and when the two do not fit side by side (large text) the amount moves under it so neither is squeezed.
public struct AmountRow: View {
    private let title: Text
    private let cents: Int
    private let style: TypeStyle

    public init(_ title: LocalizedStringKey, cents: Int, style: TypeStyle = .amount) {
        self.title = Text(title)
        self.cents = cents
        self.style = style
    }

    public init(verbatim title: String, cents: Int, style: TypeStyle = .amount) {
        self.title = Text(verbatim: title)
        self.cents = cents
        self.style = style
    }

    public var body: some View {
        AdaptiveStack(rowAlignment: .firstTextBaseline, rowSpacing: Spacing.sm, stackedSpacing: Spacing.xxs) {
            description
            MoneyText(cents: cents, style: style)
        }
        .accessibilityElement(children: .combine)
    }

    private var description: some View {
        title
            .espText(.body)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
