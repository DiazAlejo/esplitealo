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
    @ScaledMetric private var size: Double
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(style: TypeStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.spec.size, relativeTo: style.spec.textStyle.fontTextStyle)
    }

    private var font: Font {
        let spec = style.spec
        var font: Font
        switch spec.family {
        case .system:
            font = .system(size: size, weight: spec.weight.fontWeight)
        case .systemRounded:
            font = .system(size: size, weight: spec.weight.fontWeight, design: .rounded)
        case let .unkempt(weight):
            font = .custom(weight.postScriptName, fixedSize: size)
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
