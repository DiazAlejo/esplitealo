import SwiftUI

extension DynamicTextStyle {
    var fontTextStyle: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .headline: .headline
        case .body: .body
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption
        }
    }
}

extension TypeWeight {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

extension View {
    /// Sets text in one of the design system's styles. Sizes scale with Dynamic Type relative to the style's
    /// system text style; text wraps (only the display amount may shrink, and only at accessibility sizes).
    public func espText(_ style: TypeStyle) -> some View {
        modifier(EspTextModifier(style: style))
    }
}

private struct EspTextModifier: ViewModifier {
    let style: TypeStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Only the display amount has no system text style of its own size (40 pt), so only it scales by hand.
    @ScaledMetric private var displayAmountSize: Double

    init(style: TypeStyle) {
        self.style = style
        _displayAmountSize = ScaledMetric(wrappedValue: style.spec.size, relativeTo: style.spec.textStyle.fontTextStyle)
    }

    /// System styles use the system text style that has the guide's size (title2 = 22, body = 17, subheadline = 15,
    /// footnote = 13, caption = 12), so they scale exactly like system text. Unkempt scales relative to its style.
    private var font: Font {
        let spec = style.spec
        let weight = spec.weight.fontWeight
        var font: Font
        switch spec.family {
        case .system:
            font = .system(spec.textStyle.fontTextStyle, design: .default, weight: weight)
        case .systemRounded:
            font = style == .displayAmount
                ? .system(size: displayAmountSize, weight: weight, design: .rounded)
                : .system(spec.textStyle.fontTextStyle, design: .rounded, weight: weight)
        case let .unkempt(unkemptWeight):
            font = .custom(unkemptWeight.postScriptName, size: spec.size, relativeTo: spec.textStyle.fontTextStyle)
        }
        if spec.monospacedDigits { font = font.monospacedDigit() }
        return font
    }

    func body(content: Content) -> some View {
        let shrinks = style.spec.minimumScaleFactor != nil && dynamicTypeSize.isAccessibilitySize
        return content
            .font(font)
            .lineLimit(shrinks ? 1 : nil)
            .minimumScaleFactor(shrinks ? style.spec.minimumScaleFactor ?? 1 : 1)
    }
}
